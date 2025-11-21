#!/bin/bash
# Generated script to run benchmarks with specific counts

OUTPUT_FILE="${1:-results.txt}"
COUNT="${2:-6}"

# Package: github.com/tetratelabs/wazero/internal/integration_test/bench
./wazero_RISC-V-Static -test.run=none -test.bench=^BenchmarkInvocation/interpreter/fib_for_20$ -test.benchtime=65x -test.count=$COUNT | tee -a "$OUTPUT_FILE"
./wazero_RISC-V-Static -test.run=none -test.bench=^BenchmarkInvocation/interpreter/string_manipulation_size_50$ -test.benchtime=30x -test.count=$COUNT | tee -a "$OUTPUT_FILE"
./wazero_RISC-V-Static -test.run=none -test.bench=^BenchmarkInvocation/interpreter/random_mat_mul_size_20$ -test.benchtime=21x -test.count=$COUNT | tee -a "$OUTPUT_FILE"

# Package: github.com/aws/aws-sdk-go/private/protocol/json/jsonutil
./aws_jsonutil_RISC-V-Static -test.run=none -test.bench=^BenchmarkBuildJSON$ -test.benchtime=11184x -test.count=$COUNT | tee -a "$OUTPUT_FILE"
./aws_jsonutil_RISC-V-Static -test.run=none -test.bench=^BenchmarkStdlibJSON$ -test.benchtime=16126x -test.count=$COUNT | tee -a "$OUTPUT_FILE"

# Package: github.com/ethereum/go-ethereum/common/bitutil
./ethereum_bitutil_RISC-V-Static -test.run=none -test.bench=^BenchmarkFastTest2KB$ -test.benchtime=33333x -test.count=$COUNT | tee -a "$OUTPUT_FILE"
./ethereum_bitutil_RISC-V-Static -test.run=none -test.bench=^BenchmarkBaseTest2KB$ -test.benchtime=33333x -test.count=$COUNT | tee -a "$OUTPUT_FILE"
./ethereum_bitutil_RISC-V-Static -test.run=none -test.bench=^BenchmarkEncoding4KBVerySparse$ -test.benchtime=3755x -test.count=$COUNT | tee -a "$OUTPUT_FILE"

# Package: github.com/ethereum/go-ethereum/crypto/ecies
./ethereum_ecies_RISC-V-Static -test.run=none -test.bench=^BenchmarkGenerateKeyP256$ -test.benchtime=809x -test.count=$COUNT | tee -a "$OUTPUT_FILE"
./ethereum_ecies_RISC-V-Static -test.run=none -test.bench=^BenchmarkGenSharedKeyP256$ -test.benchtime=183x -test.count=$COUNT | tee -a "$OUTPUT_FILE"
./ethereum_ecies_RISC-V-Static -test.run=none -test.bench=^BenchmarkGenSharedKeyS256$ -test.benchtime=312x -test.count=$COUNT | tee -a "$OUTPUT_FILE"

# Package: github.com/ethereum/go-ethereum/core/vm
./ethereum_corevm_RISC-V-Static -test.run=none -test.bench=^BenchmarkOpDiv128$ -test.benchtime=481002x -test.count=$COUNT | tee -a "$OUTPUT_FILE"

# Package: github.com/ethereum/go-ethereum/trie
./ethereum_trie_RISC-V-Static -test.run=none -test.bench=^BenchmarkHashFixedSize/10K$ -test.benchtime=7x -test.count=$COUNT | tee -a "$OUTPUT_FILE"
./ethereum_trie_RISC-V-Static -test.run=none -test.bench=^BenchmarkCommitAfterHashFixedSize/10K$ -test.benchtime=11x -test.count=$COUNT | tee -a "$OUTPUT_FILE"

# Package: gonum.org/v1/gonum/blas/gonum
./gonum_blas_native_RISC-V-Static -test.run=none -test.bench=^BenchmarkDnrm2MediumPosInc$ -test.benchtime=15849x -test.count=$COUNT | tee -a "$OUTPUT_FILE"
./gonum_blas_native_RISC-V-Static -test.run=none -test.bench=^BenchmarkDasumMediumUnitaryInc$ -test.benchtime=60040x -test.count=$COUNT | tee -a "$OUTPUT_FILE"

# Package: gonum.org/v1/gonum/lapack/gonum
./gonum_lapack_native_RISC-V-Static -test.run=none -test.bench=^BenchmarkDgeev/Circulant10$ -test.benchtime=1409x -test.count=$COUNT | tee -a "$OUTPUT_FILE"
./gonum_lapack_native_RISC-V-Static -test.run=none -test.bench=^BenchmarkDgeev/Circulant100$ -test.benchtime=22x -test.count=$COUNT | tee -a "$OUTPUT_FILE"

# Package: gonum.org/v1/gonum/mat
./gonum_mat_RISC-V-Static -test.run=none -test.bench=^BenchmarkMulWorkspaceDense1000Hundredth$ -test.benchtime=10x -test.count=$COUNT | tee -a "$OUTPUT_FILE"
./gonum_mat_RISC-V-Static -test.run=none -test.bench=^BenchmarkScaleVec10000Inc20$ -test.benchtime=3624x -test.count=$COUNT | tee -a "$OUTPUT_FILE"

# Package: github.com/Masterminds/semver
./semver_RISC-V-Static -test.run=none -test.bench=^BenchmarkValidateVersionTildeFail$ -test.benchtime=58454x -test.count=$COUNT | tee -a "$OUTPUT_FILE"

# Package: k8s.io/client-go/tools/cache
./k8s_cache_RISC-V-Static -test.run=none -test.bench=^BenchmarkListener$ -test.benchtime=44655x -test.count=$COUNT | tee -a "$OUTPUT_FILE"
./k8s_cache_RISC-V-Static -test.run=none -test.bench=^BenchmarkReflectorResyncChanMany$ -test.benchtime=59874x -test.count=$COUNT | tee -a "$OUTPUT_FILE"

# Package: k8s.io/client-go/util/workqueue
./k8s_workqueue_RISC-V-Static -test.run=none -test.bench=^BenchmarkParallelizeUntil/pieces:1000,workers:10,chunkSize:1$ -test.benchtime=460x -test.count=$COUNT | tee -a "$OUTPUT_FILE"
./k8s_workqueue_RISC-V-Static -test.run=none -test.bench=^BenchmarkParallelizeUntil/pieces:1000,workers:10,chunkSize:10$ -test.benchtime=1652x -test.count=$COUNT | tee -a "$OUTPUT_FILE"
./k8s_workqueue_RISC-V-Static -test.run=none -test.bench=^BenchmarkParallelizeUntil/pieces:1000,workers:10,chunkSize:100$ -test.benchtime=2209x -test.count=$COUNT | tee -a "$OUTPUT_FILE"
./k8s_workqueue_RISC-V-Static -test.run=none -test.bench=^BenchmarkParallelizeUntil/pieces:999,workers:10,chunkSize:13$ -test.benchtime=1747x -test.count=$COUNT | tee -a "$OUTPUT_FILE"

# Package: gonum.org/v1/gonum/graph/topo
./gonum_topo_RISC-V-Static -test.run=none -test.bench=^BenchmarkTarjanSCCGnp_10_tenth$ -test.benchtime=6227x -test.count=$COUNT | tee -a "$OUTPUT_FILE"
./gonum_topo_RISC-V-Static -test.run=none -test.bench=^BenchmarkTarjanSCCGnp_1000_half$ -test.benchtime=12x -test.count=$COUNT | tee -a "$OUTPUT_FILE"

# Package: gonum.org/v1/gonum/graph/community
./gonum_community_RISC-V-Static -test.run=none -test.bench=^BenchmarkLouvainDirectedMultiplex$ -test.benchtime=11x -test.count=$COUNT | tee -a "$OUTPUT_FILE"

# Package: gonum.org/v1/gonum/graph/traverse
./gonum_traverse_RISC-V-Static -test.run=none -test.bench=^BenchmarkWalkAllBreadthFirstGnp_10_tenth$ -test.benchtime=13083x -test.count=$COUNT | tee -a "$OUTPUT_FILE"
./gonum_traverse_RISC-V-Static -test.run=none -test.bench=^BenchmarkWalkAllBreadthFirstGnp_1000_tenth$ -test.benchtime=16x -test.count=$COUNT | tee -a "$OUTPUT_FILE"

# Package: zombiezen.com/go/capnproto2
./capnproto2_RISC-V-Static -test.run=none -test.bench=^BenchmarkTextMovementBetweenSegments$ -test.benchtime=97x -test.count=$COUNT | tee -a "$OUTPUT_FILE"
./capnproto2_RISC-V-Static -test.run=none -test.bench=^BenchmarkGrowth_MultiSegment$ -test.benchtime=15x -test.count=$COUNT | tee -a "$OUTPUT_FILE"

# Package: go.uber.org/zap/zapcore
./uber_zap_RISC-V-Static -test.run=none -test.bench=^BenchmarkBufferedWriteSyncer/write_file_with_buffer$ -test.benchtime=702179x -test.count=$COUNT | tee -a "$OUTPUT_FILE"
./uber_zap_RISC-V-Static -test.run=none -test.bench=^BenchmarkMultiWriteSyncer/2_discarder$ -test.benchtime=894439x -test.count=$COUNT | tee -a "$OUTPUT_FILE"
./uber_zap_RISC-V-Static -test.run=none -test.bench=^BenchmarkMultiWriteSyncer/4_discarder$ -test.benchtime=716364x -test.count=$COUNT | tee -a "$OUTPUT_FILE"
./uber_zap_RISC-V-Static -test.run=none -test.bench=^BenchmarkMultiWriteSyncer/4_discarder_with_buffer$ -test.benchtime=792087x -test.count=$COUNT | tee -a "$OUTPUT_FILE"
./uber_zap_RISC-V-Static -test.run=none -test.bench=^BenchmarkWriteSyncer/write_file_with_no_buffer$ -test.benchtime=61928x -test.count=$COUNT | tee -a "$OUTPUT_FILE"
./uber_zap_RISC-V-Static -test.run=none -test.bench=^BenchmarkZapConsole$ -test.benchtime=23387x -test.count=$COUNT | tee -a "$OUTPUT_FILE"
./uber_zap_RISC-V-Static -test.run=none -test.bench=^BenchmarkJSONLogMarshalerFunc$ -test.benchtime=72418x -test.count=$COUNT | tee -a "$OUTPUT_FILE"
./uber_zap_RISC-V-Static -test.run=none -test.bench=^BenchmarkZapJSON$ -test.benchtime=27363x -test.count=$COUNT | tee -a "$OUTPUT_FILE"
./uber_zap_RISC-V-Static -test.run=none -test.bench=^BenchmarkStandardJSON$ -test.benchtime=10365x -test.count=$COUNT | tee -a "$OUTPUT_FILE"
./uber_zap_RISC-V-Static -test.run=none -test.bench=^BenchmarkSampler_Check/7_keys$ -test.benchtime=1393156x -test.count=$COUNT | tee -a "$OUTPUT_FILE"
./uber_zap_RISC-V-Static -test.run=none -test.bench=^BenchmarkSampler_Check/50_keys$ -test.benchtime=1159051x -test.count=$COUNT | tee -a "$OUTPUT_FILE"
./uber_zap_RISC-V-Static -test.run=none -test.bench=^BenchmarkSampler_Check/100_keys$ -test.benchtime=1159327x -test.count=$COUNT | tee -a "$OUTPUT_FILE"
./uber_zap_RISC-V-Static -test.run=none -test.bench=^BenchmarkSampler_CheckWithHook/7_keys$ -test.benchtime=1372389x -test.count=$COUNT | tee -a "$OUTPUT_FILE"
./uber_zap_RISC-V-Static -test.run=none -test.bench=^BenchmarkSampler_CheckWithHook/50_keys$ -test.benchtime=1233120x -test.count=$COUNT | tee -a "$OUTPUT_FILE"
./uber_zap_RISC-V-Static -test.run=none -test.bench=^BenchmarkSampler_CheckWithHook/100_keys$ -test.benchtime=1227319x -test.count=$COUNT | tee -a "$OUTPUT_FILE"
./uber_zap_RISC-V-Static -test.run=none -test.bench=^BenchmarkTeeCheck$ -test.benchtime=54802x -test.count=$COUNT | tee -a "$OUTPUT_FILE"

# Package: github.com/uber-go/tally
./uber_tally_RISC-V-Static -test.run=none -test.bench=^BenchmarkScopeTaggedNoCachedSubscopes$ -test.benchtime=10804x -test.count=$COUNT | tee -a "$OUTPUT_FILE"
./uber_tally_RISC-V-Static -test.run=none -test.bench=^BenchmarkHistogramAllocation$ -test.benchtime=22896x -test.count=$COUNT | tee -a "$OUTPUT_FILE"

# Package: github.com/gtank/blake2s
./gtank_blake2s_RISC-V-Static -test.run=none -test.bench=^BenchmarkHash8K$ -test.benchtime=1897x -test.count=$COUNT | tee -a "$OUTPUT_FILE"

# Package: github.com/ajstarks/deck/generate
./ajstarks_deck_generate_RISC-V-Static -test.run=none -test.bench=^BenchmarkArc$ -test.benchtime=15300x -test.count=$COUNT | tee -a "$OUTPUT_FILE"
./ajstarks_deck_generate_RISC-V-Static -test.run=none -test.bench=^BenchmarkPolygon$ -test.benchtime=7727x -test.count=$COUNT | tee -a "$OUTPUT_FILE"

# Package: github.com/benhoyt/goawk/interp
./benhoyt_goawk_1_18_RISC-V-Static -test.run=none -test.bench=^BenchmarkRecursiveFunc$ -test.benchtime=2868x -test.count=$COUNT | tee -a "$OUTPUT_FILE"
./benhoyt_goawk_1_18_RISC-V-Static -test.run=none -test.bench=^BenchmarkRegexMatch$ -test.benchtime=43903x -test.count=$COUNT | tee -a "$OUTPUT_FILE"
./benhoyt_goawk_1_18_RISC-V-Static -test.run=none -test.bench=^BenchmarkRepeatExecProgram$ -test.benchtime=4045x -test.count=$COUNT | tee -a "$OUTPUT_FILE"
./benhoyt_goawk_1_18_RISC-V-Static -test.run=none -test.bench=^BenchmarkRepeatNew$ -test.benchtime=341711x -test.count=$COUNT | tee -a "$OUTPUT_FILE"
./benhoyt_goawk_1_18_RISC-V-Static -test.run=none -test.bench=^BenchmarkRepeatIOExecProgram$ -test.benchtime=2412x -test.count=$COUNT | tee -a "$OUTPUT_FILE"
./benhoyt_goawk_1_18_RISC-V-Static -test.run=none -test.bench=^BenchmarkRepeatIONew$ -test.benchtime=33333x -test.count=$COUNT | tee -a "$OUTPUT_FILE"

# Package: github.com/dustin/go-broadcast
./dustin_broadcast_RISC-V-Static -test.run=none -test.bench=^BenchmarkDirectSend$ -test.benchtime=76784x -test.count=$COUNT | tee -a "$OUTPUT_FILE"
./dustin_broadcast_RISC-V-Static -test.run=none -test.bench=^BenchmarkParallelDirectSend$ -test.benchtime=76807x -test.count=$COUNT | tee -a "$OUTPUT_FILE"
./dustin_broadcast_RISC-V-Static -test.run=none -test.bench=^BenchmarkParallelBrodcast$ -test.benchtime=47806x -test.count=$COUNT | tee -a "$OUTPUT_FILE"
./dustin_broadcast_RISC-V-Static -test.run=none -test.bench=^BenchmarkMuxBrodcast$ -test.benchtime=54071x -test.count=$COUNT | tee -a "$OUTPUT_FILE"

# Package: github.com/dustin/go-humanize
./dustin_humanize_RISC-V-Static -test.run=none -test.bench=^BenchmarkParseBigBytes$ -test.benchtime=30982x -test.count=$COUNT | tee -a "$OUTPUT_FILE"

# Package: github.com/bits-and-blooms/bloom/v3
./bloom_bloom_RISC-V-Static -test.run=none -test.bench=^BenchmarkSeparateTestAndAdd$ -test.benchtime=126871x -test.count=$COUNT | tee -a "$OUTPUT_FILE"
./bloom_bloom_RISC-V-Static -test.run=none -test.bench=^BenchmarkCombinedTestAndAdd$ -test.benchtime=156258x -test.count=$COUNT | tee -a "$OUTPUT_FILE"

# Package: github.com/flanglet/kanzi-go/benchmark
./kanzi_RISC-V-Static -test.run=none -test.bench=^BenchmarkFPAQ$ -test.benchtime=12x -test.count=$COUNT | tee -a "$OUTPUT_FILE"
./kanzi_RISC-V-Static -test.run=none -test.bench=^BenchmarkLZ$ -test.benchtime=121x -test.count=$COUNT | tee -a "$OUTPUT_FILE"
./kanzi_RISC-V-Static -test.run=none -test.bench=^BenchmarkMTFT$ -test.benchtime=32x -test.count=$COUNT | tee -a "$OUTPUT_FILE"

