// Copyright 2021 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package harnesses

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"

	"golang.org/x/benchmarks/sweet/common"
	"golang.org/x/benchmarks/sweet/common/log"
)

type localBenchHarness struct {
	binName   string
	genArgs   func(cfg *common.Config, rcfg *common.RunConfig) []string
	beforeRun func(cfg *common.Config, rcfg *common.RunConfig) error
}

func (h *localBenchHarness) CheckPrerequisites() error {
	return nil
}

func (h *localBenchHarness) Get(_ *common.GetConfig) error {
	return nil
}

func (h *localBenchHarness) Build(cfg *common.Config, bcfg *common.BuildConfig) error {
	targetBin := filepath.Join(bcfg.BinDir, h.binName)

	// Check for prebuilt binary if prebuilt binary directory is specified
	if bcfg.PrebuiltBinaryDir != "" {
		// Construct prebuilt binary path: prebuilt-binary-dir/benchmark-name
		prebuiltBin := filepath.Join(bcfg.PrebuiltBinaryDir, h.binName)
		log.Printf("Checking for prebuilt binary from -prebuilt-binary-dir: %s", prebuiltBin)

		if info, err := os.Stat(prebuiltBin); err == nil && !info.IsDir() {
			// Prebuilt binary exists, copy it instead of building
			if bcfg.BuildLog != nil {
				fmt.Fprintf(bcfg.BuildLog, "Prebuilt binary found at %s, copying to %s\n", prebuiltBin, targetBin)
			}
			log.Printf("✓ Successfully using prebuilt binary from -prebuilt-binary-dir: %s -> %s", prebuiltBin, targetBin)

			// Read the prebuilt binary
			srcData, err := os.ReadFile(prebuiltBin)
			if err != nil {
				return fmt.Errorf("failed to read prebuilt binary %s: %w", prebuiltBin, err)
			}

			// Write to target location
			if err := os.WriteFile(targetBin, srcData, 0755); err != nil {
				return fmt.Errorf("failed to write binary to %s: %w", targetBin, err)
			}

			log.Printf("✓ Prebuilt binary copied successfully: %s (size: %d bytes)", targetBin, len(srcData))
			return nil
		} else if err != nil && !os.IsNotExist(err) {
			// Error other than file not found
			log.Printf("✗ Error checking prebuilt binary %s: %v", prebuiltBin, err)
			return fmt.Errorf("failed to check prebuilt binary %s: %w", prebuiltBin, err)
		}
		// Prebuilt binary doesn't exist, fall through to normal build
		log.Printf("✗ Prebuilt binary not found at %s (from -prebuilt-binary-dir), will build from source", prebuiltBin)
		if bcfg.BuildLog != nil {
			fmt.Fprintf(bcfg.BuildLog, "Prebuilt binary not found at %s, building from source\n", prebuiltBin)
		}
	}

	// Normal build path
	return cfg.GoTool(bcfg.BuildLog).BuildPath(bcfg.BenchDir, targetBin)
}

func (h *localBenchHarness) Run(cfg *common.Config, rcfg *common.RunConfig) error {
	if h.beforeRun != nil {
		if err := h.beforeRun(cfg, rcfg); err != nil {
			return err
		}
	}
	cmd := exec.Command(
		filepath.Join(rcfg.BinDir, h.binName),
		append(rcfg.Args, h.genArgs(cfg, rcfg)...)...,
	)
	cmd.Env = cfg.ExecEnv.Collapse()
	cmd.Stdout = rcfg.Results
	cmd.Stderr = rcfg.Log
	log.TraceCommand(cmd, false)
	return cmd.Run()
}

func BiogoIgor() common.Harness {
	return &localBenchHarness{
		binName: "biogo-igor-bench",
		genArgs: func(cfg *common.Config, rcfg *common.RunConfig) []string {
			return []string{
				filepath.Join(rcfg.AssetsDir, "Homo_sapiens.GRCh38.dna.chromosome.22.gff"),
			}
		},
	}
}

func BiogoKrishna() common.Harness {
	return &localBenchHarness{
		binName: "biogo-krishna-bench",
		genArgs: func(cfg *common.Config, rcfg *common.RunConfig) []string {
			return []string{
				"-alignconc",
				"-tmp", rcfg.TmpDir,
				"-tmpconc",
				filepath.Join(rcfg.AssetsDir, "Mus_musculus.GRCm38.dna.nonchromosomal.fa"),
			}
		},
	}
}

func BleveIndex() common.Harness {
	return &localBenchHarness{
		binName: "bleve-index-bench",
		genArgs: func(cfg *common.Config, rcfg *common.RunConfig) []string {
			var args []string
			if rcfg.Short {
				args = []string{
					"-documents", "10",
					"-batch-size", "10",
				}
			} else {
				args = []string{
					"-documents", "1000",
					"-batch-size", "100",
				}
			}
			return append(args, filepath.Join(rcfg.AssetsDir, "enwiki-20080103-pages-articles.xml.bz2"))
		},
	}
}

func GopherLua() common.Harness {
	return &localBenchHarness{
		binName: "gopher-lua-bench",
		genArgs: func(cfg *common.Config, rcfg *common.RunConfig) []string {
			args := []string{
				filepath.Join(rcfg.AssetsDir, "k-nucleotide.lua"),
				filepath.Join(rcfg.AssetsDir, "input.txt"),
			}
			if rcfg.Short {
				args = append([]string{"-short"}, args...)
			}
			return args
		},
	}
}

func Markdown() common.Harness {
	return &localBenchHarness{
		binName: "markdown-bench",
		genArgs: func(cfg *common.Config, rcfg *common.RunConfig) []string {
			return []string{
				rcfg.AssetsDir,
			}
		},
	}
}
