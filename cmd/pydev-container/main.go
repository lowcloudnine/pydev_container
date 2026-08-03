// pydev-container starts the development image with a selected directory and
// provides a token-protected bridge to the host clipboard.
package main

import (
	"context"
	"crypto/rand"
	"crypto/subtle"
	"encoding/base64"
	"errors"
	"flag"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"time"
)

const (
	defaultImage       = "pydev-container"
	defaultMountTarget = "/workspace"
	maxClipboardBytes  = 5 << 20
)

func main() {
	if len(os.Args) < 2 {
		usage()
		os.Exit(2)
	}

	var err error
	switch os.Args[1] {
	case "run":
		err = run(os.Args[2:])
	case "clipboard":
		err = clipboard(os.Args[2:])
	case "help", "-h", "--help":
		usage()
		return
	default:
		err = fmt.Errorf("unknown command %q", os.Args[1])
	}
	if err != nil {
		fmt.Fprintln(os.Stderr, "pydev-container:", err)
		os.Exit(1)
	}
}

func usage() {
	fmt.Fprint(os.Stderr, `Usage:
  pydev-container run --path PATH [--image IMAGE] [--target PATH] [-- COMMAND...]
  pydev-container clipboard copy
  pydev-container clipboard paste

run starts Docker, bind-mounts PATH, and makes the host clipboard available to
the container. clipboard is used inside the launched container.
`)
}

func run(args []string) error {
	flags := flag.NewFlagSet("run", flag.ContinueOnError)
	flags.SetOutput(os.Stderr)
	hostPath := flags.String("path", "", "existing host file or directory to mount")
	image := flags.String("image", defaultImage, "Docker image to run")
	target := flags.String("target", defaultMountTarget, "absolute mount path in the container")
	if err := flags.Parse(args); err != nil {
		return err
	}
	if *hostPath == "" {
		return errors.New("--path is required")
	}
	if !filepath.IsAbs(*target) {
		return errors.New("--target must be an absolute container path")
	}
	absPath, err := filepath.Abs(*hostPath)
	if err != nil {
		return fmt.Errorf("resolve --path: %w", err)
	}
	if _, err := os.Stat(absPath); err != nil {
		return fmt.Errorf("mounted path %q: %w", absPath, err)
	}

	token, err := newToken()
	if err != nil {
		return err
	}
	bridge, err := startBridge(token)
	if err != nil {
		return err
	}
	defer bridge.Close(context.Background())

	docker, err := exec.LookPath("docker")
	if err != nil {
		return errors.New("Docker CLI was not found in PATH")
	}
	dockerArgs := []string{
		"run", "--rm", "-it",
		"--mount", fmt.Sprintf("type=bind,src=%s,dst=%s", absPath, *target),
		"--env", "PYDEV_CLIPBOARD_URL=" + bridge.containerURL(),
		"--env", "PYDEV_CLIPBOARD_TOKEN=" + token,
		"--workdir", *target,
		*image,
	}
	// Docker Desktop provides host.docker.internal on Windows and macOS. Native
	// Linux Docker needs this explicit gateway mapping.
	if runtime.GOOS == "linux" {
		dockerArgs = append(dockerArgs[:3], append([]string{"--add-host", "host.docker.internal:host-gateway"}, dockerArgs[3:]...)...)
	}
	dockerArgs = append(dockerArgs, flags.Args()...)

	cmd := exec.Command(docker, dockerArgs...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

type clipboardBridge struct {
	server *http.Server
	port   int
}

func startBridge(token string) (*clipboardBridge, error) {
	listener, err := net.Listen("tcp4", "0.0.0.0:0")
	if err != nil {
		return nil, fmt.Errorf("start clipboard bridge: %w", err)
	}
	port := listener.Addr().(*net.TCPAddr).Port
	bridge := &clipboardBridge{port: port}
	bridge.server = &http.Server{
		Handler:           bridge.handler(token),
		ReadHeaderTimeout: 5 * time.Second,
	}
	go func() {
		if err := bridge.server.Serve(listener); err != nil && !errors.Is(err, http.ErrServerClosed) {
			fmt.Fprintln(os.Stderr, "clipboard bridge:", err)
		}
	}()
	return bridge, nil
}

func (b *clipboardBridge) Close(ctx context.Context) error {
	shutdownCtx, cancel := context.WithTimeout(ctx, 2*time.Second)
	defer cancel()
	return b.server.Shutdown(shutdownCtx)
}

func (b *clipboardBridge) containerURL() string {
	return fmt.Sprintf("http://host.docker.internal:%d", b.port)
}

func (b *clipboardBridge) handler(token string) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		provided := strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer ")
		if subtle.ConstantTimeCompare([]byte(provided), []byte(token)) != 1 {
			http.Error(w, "unauthorized", http.StatusUnauthorized)
			return
		}
		if r.URL.Path != "/v1/clipboard" {
			http.NotFound(w, r)
			return
		}

		ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
		defer cancel()
		switch r.Method {
		case http.MethodGet:
			text, err := readHostClipboard(ctx)
			if err != nil {
				http.Error(w, err.Error(), http.StatusInternalServerError)
				return
			}
			w.Header().Set("Content-Type", "text/plain; charset=utf-8")
			_, _ = io.WriteString(w, text)
		case http.MethodPost:
			defer r.Body.Close()
			text, err := io.ReadAll(io.LimitReader(r.Body, maxClipboardBytes+1))
			if err != nil {
				http.Error(w, "read clipboard data", http.StatusBadRequest)
				return
			}
			if len(text) > maxClipboardBytes {
				http.Error(w, "clipboard data exceeds 5 MiB", http.StatusRequestEntityTooLarge)
				return
			}
			if err := writeHostClipboard(ctx, text); err != nil {
				http.Error(w, err.Error(), http.StatusInternalServerError)
				return
			}
			w.WriteHeader(http.StatusNoContent)
		default:
			w.Header().Set("Allow", "GET, POST")
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		}
	})
}

func clipboard(args []string) error {
	if len(args) != 1 || (args[0] != "copy" && args[0] != "paste") {
		return errors.New("usage: pydev-container clipboard copy|paste")
	}
	url, token := os.Getenv("PYDEV_CLIPBOARD_URL"), os.Getenv("PYDEV_CLIPBOARD_TOKEN")
	if url == "" || token == "" {
		return errors.New("clipboard bridge is unavailable; start the container with pydev-container run")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if args[0] == "copy" {
		body, err := io.ReadAll(io.LimitReader(os.Stdin, maxClipboardBytes+1))
		if err != nil {
			return err
		}
		if len(body) > maxClipboardBytes {
			return errors.New("clipboard data exceeds 5 MiB")
		}
		req, err := http.NewRequestWithContext(ctx, http.MethodPost, url+"/v1/clipboard", strings.NewReader(string(body)))
		if err != nil {
			return err
		}
		req.Header.Set("Authorization", "Bearer "+token)
		response, err := http.DefaultClient.Do(req)
		if err != nil {
			return fmt.Errorf("contact clipboard bridge: %w", err)
		}
		defer response.Body.Close()
		if response.StatusCode != http.StatusNoContent {
			message, _ := io.ReadAll(io.LimitReader(response.Body, 4096))
			return fmt.Errorf("clipboard bridge returned %s: %s", response.Status, strings.TrimSpace(string(message)))
		}
		return nil
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url+"/v1/clipboard", nil)
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+token)
	response, err := http.DefaultClient.Do(req)
	if err != nil {
		return fmt.Errorf("contact clipboard bridge: %w", err)
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		message, _ := io.ReadAll(io.LimitReader(response.Body, 4096))
		return fmt.Errorf("clipboard bridge returned %s: %s", response.Status, strings.TrimSpace(string(message)))
	}
	_, err = io.Copy(os.Stdout, io.LimitReader(response.Body, maxClipboardBytes+1))
	return err
}

func newToken() (string, error) {
	bytes := make([]byte, 32)
	if _, err := rand.Read(bytes); err != nil {
		return "", fmt.Errorf("generate clipboard token: %w", err)
	}
	return base64.RawURLEncoding.EncodeToString(bytes), nil
}

func writeHostClipboard(ctx context.Context, text []byte) error {
	commands := clipboardCommands(true)
	var failures []string
	for _, command := range commands {
		cmd := exec.CommandContext(ctx, command.name, command.args...)
		cmd.Stdin = strings.NewReader(string(text))
		if output, err := cmd.CombinedOutput(); err == nil {
			return nil
		} else {
			failures = append(failures, fmt.Sprintf("%s: %s", command.name, strings.TrimSpace(string(output))))
		}
	}
	return fmt.Errorf("write host clipboard failed (%s)", strings.Join(failures, "; "))
}

func readHostClipboard(ctx context.Context) (string, error) {
	commands := clipboardCommands(false)
	var failures []string
	for _, command := range commands {
		output, err := exec.CommandContext(ctx, command.name, command.args...).Output()
		if err == nil {
			return string(output), nil
		}
		failures = append(failures, command.name)
	}
	return "", fmt.Errorf("read host clipboard failed; tried %s", strings.Join(failures, ", "))
}

type clipboardCommand struct {
	name string
	args []string
}

func clipboardCommands(write bool) []clipboardCommand {
	switch runtime.GOOS {
	case "darwin":
		if write {
			return []clipboardCommand{{name: "pbcopy"}}
		}
		return []clipboardCommand{{name: "pbpaste"}}
	case "windows":
		if write {
			return []clipboardCommand{{name: "powershell.exe", args: []string{"-NoProfile", "-NonInteractive", "-Command", "Set-Clipboard -Value ([Console]::In.ReadToEnd())"}}}
		}
		return []clipboardCommand{{name: "powershell.exe", args: []string{"-NoProfile", "-NonInteractive", "-Command", "Get-Clipboard -Raw"}}}
	default:
		if write {
			return []clipboardCommand{{name: "wl-copy"}, {name: "xclip", args: []string{"-selection", "clipboard"}}}
		}
		return []clipboardCommand{{name: "wl-paste"}, {name: "xclip", args: []string{"-selection", "clipboard", "-o"}}}
	}
}
