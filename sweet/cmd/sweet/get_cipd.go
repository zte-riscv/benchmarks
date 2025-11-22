// Copyright 2021 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build !wasm && !plan9

package main

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"time"

	"go.chromium.org/luci/cipd/client/cipd"
	"go.chromium.org/luci/cipd/client/cipd/pkg"
	cipdc "go.chromium.org/luci/cipd/common"
	"go.chromium.org/luci/hardcoded/chromeinfra"
	"golang.org/x/benchmarks/sweet/cli/assets"
	"golang.org/x/benchmarks/sweet/common/log"
)

// dirSize calculates the total size of a directory in bytes.
func dirSize(path string) (int64, error) {
	var size int64
	err := filepath.Walk(path, func(_ string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if !info.IsDir() {
			size += info.Size()
		}
		return nil
	})
	return size, err
}

// formatBytes converts bytes to a human-readable string.
func formatBytes(bytes int64) string {
	const unit = 1024
	if bytes < unit {
		return fmt.Sprintf("%d B", bytes)
	}
	units := "KMGTPE"
	div, exp := int64(unit), 0
	for n := bytes / unit; n >= unit && exp < len(units)-1; n /= unit {
		div *= unit
		exp++
	}
	return fmt.Sprintf("%.2f %cB", float64(bytes)/float64(div), units[exp])
}

func (c *getCmd) Run(_ []string) error {
	log.SetActivityLog(true)
	ctx := context.Background()

	// Do some cleanup, if needed.
	if c.clean {
		for {
			log.Printf("Deleting cache directory %s", c.cache)
			fmt.Print("This is a destructive action. Please confirm. (y/n): ")
			var r string
			_, err := fmt.Scanf("%s\n", &r)
			if err != nil {
				fmt.Printf("Invalid input: %v\n", err)
			} else {
				if r == "y" {
					break
				} else if r == "n" {
					return nil
				} else {
					fmt.Println("Input must be exactly 'y' or 'n'.")
				}
			}
		}
		if err := os.RemoveAll(c.cache); err != nil {
			return fmt.Errorf("failed to delete cache directory %s: %v", c.cache, err)
		}
	}

	// Load CIPD options, including auth, cache dir, etc. from env. The package is public, but we
	// want to be authenticated transparently when we pull the assets down on the builders.
	var opts cipd.ClientOptions
	if err := opts.LoadFromEnv(ctx); err != nil {
		return err
	}
	if opts.ServiceURL == "" {
		opts.ServiceURL = chromeinfra.CIPDServiceURL
	}
	// Use an existing CIPD cache in the environment, if available.
	// Otherwise, set up the default.
	if opts.CacheDir == "" {
		opts.CacheDir = filepath.Join(c.cache, assets.CIPDCacheDir)
	}

	// Figure out the destination directory.
	var ensureOpts cipd.EnsureOptions
	ensureOpts.Paranoia = cipd.CheckIntegrity
	if c.copyDir != "" {
		ensureOpts.OverrideInstallMode = pkg.InstallModeCopy
		opts.Root = c.copyDir
	} else {
		assetsDir, err := assets.CachedAssets(c.cache, c.version)
		if err == nil {
			// Nothing to do.
			return nil
		}
		if err != assets.ErrNotInCache {
			return err
		}
		opts.Root = assetsDir
	}

	// Find the assets by version.
	cc, err := cipd.NewClient(opts)
	if err != nil {
		return err
	}
	defer cc.Close(ctx)
	pins, err := cc.SearchInstances(ctx, "golang/sweet/assets", []string{"version:" + assets.ToCIPDVersion(c.version)})
	if err != nil {
		return err
	}
	if len(pins) == 0 {
		return fmt.Errorf("unable to find CIPD package instance for version %s", c.version)
	}

	log.Printf("Fetching assets %s (this may take a while, please be patient...)", c.version)
	log.Printf("Package instance: %s", pins[0])
	log.Printf("Destination: %s", opts.Root)
	log.Printf("Cache directory: %s", opts.CacheDir)
	log.Printf("CIPD service URL: %s", opts.ServiceURL)

	// Get initial sizes (may be 0 if directories don't exist yet)
	initialRootSize, _ := dirSize(opts.Root)
	initialCacheSize, _ := dirSize(opts.CacheDir)

	// Start a goroutine to show progress indicators
	var wg sync.WaitGroup
	done := make(chan struct{})
	wg.Add(1)
	go func() {
		defer wg.Done()
		ticker := time.NewTicker(5 * time.Second)
		defer ticker.Stop()
		count := 0
		for {
			select {
			case <-ticker.C:
				count++
				// Check both cache and destination directories
				cacheSize, cacheErr := dirSize(opts.CacheDir)
				rootSize, rootErr := dirSize(opts.Root)

				var downloadedSize int64
				var sizeInfo string

				if cacheErr == nil && rootErr == nil {
					cacheDownloaded := cacheSize - initialCacheSize
					rootDownloaded := rootSize - initialRootSize
					if cacheDownloaded < 0 {
						cacheDownloaded = 0
					}
					if rootDownloaded < 0 {
						rootDownloaded = 0
					}
					// Total downloaded is the sum of cache and root
					downloadedSize = cacheDownloaded + rootDownloaded
					if downloadedSize > 0 {
						sizeInfo = fmt.Sprintf(", downloaded: %s", formatBytes(downloadedSize))
					}
				} else if cacheErr == nil {
					cacheDownloaded := cacheSize - initialCacheSize
					if cacheDownloaded < 0 {
						cacheDownloaded = 0
					}
					if cacheDownloaded > 0 {
						sizeInfo = fmt.Sprintf(", cache: %s", formatBytes(cacheDownloaded))
					}
				} else if rootErr == nil {
					rootDownloaded := rootSize - initialRootSize
					if rootDownloaded < 0 {
						rootDownloaded = 0
					}
					if rootDownloaded > 0 {
						sizeInfo = fmt.Sprintf(", extracted: %s", formatBytes(rootDownloaded))
					}
				}

				elapsed := count * 5
				msg := fmt.Sprintf("Still downloading... (elapsed: %ds%s)", elapsed, sizeInfo)
				// Warn if no progress after 30 seconds
				if elapsed >= 30 && sizeInfo == "" {
					msg += " [No data received yet - check network connection]"
				}
				log.Printf(msg)
			case <-done:
				return
			}
		}
	}()

	// Fetch the instance.
	_, err = cc.EnsurePackages(ctx, map[string]cipdc.PinSlice{"": pins[:1]}, &ensureOpts)
	close(done)
	wg.Wait()

	if err != nil {
		return fmt.Errorf("fetching CIPD package instance %s: %v", pins[0], err)
	}

	// Show final size
	finalRootSize, rootErr := dirSize(opts.Root)
	finalCacheSize, cacheErr := dirSize(opts.CacheDir)

	if rootErr == nil && finalRootSize > 0 {
		totalSize := finalRootSize - initialRootSize
		if totalSize < 0 {
			totalSize = finalRootSize
		}
		log.Printf("Successfully fetched assets %s (total size: %s)", c.version, formatBytes(totalSize))
	} else if cacheErr == nil && finalCacheSize > initialCacheSize {
		// If root directory check failed, at least show cache size
		cacheSize := finalCacheSize - initialCacheSize
		log.Printf("Successfully fetched assets %s (cache size: %s)", c.version, formatBytes(cacheSize))
	} else {
		log.Printf("Successfully fetched assets %s", c.version)
	}
	return nil
}
