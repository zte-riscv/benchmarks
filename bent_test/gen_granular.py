import re
import sys

def parse_toml(toml_path):
    benchmarks = []
    current_bench = {}
    
    with open(toml_path, 'r') as f:
        content = f.read()
    
    # Simple regex to find [[Benchmarks]] blocks
    # This assumes standard formatting as seen in the file
    blocks = re.split(r'\[\[Benchmarks\]\]', content)
    
    for block in blocks:
        if not block.strip():
            continue
            
        name_match = re.search(r'Name\s*=\s*"(.*?)"', block)
        bench_match = re.search(r'Benchmarks\s*=\s*"(.*?)"', block)
        
        if name_match and bench_match:
            benchmarks.append({
                'name': name_match.group(1),
                'regex': bench_match.group(1)
            })
            
    return benchmarks

def parse_results(result_path):
    with open(result_path, 'r') as f:
        lines = f.readlines()
        
    blocks = []
    current_block = {'pkg': '', 'benchmarks': []}
    
    for line in lines:
        line = line.strip()
        if not line:
            continue
            
        if line.startswith('pkg:'):
            if current_block['pkg']:
                blocks.append(current_block)
            current_block = {'pkg': line.split('pkg:')[1].strip(), 'benchmarks': []}
        elif line.startswith('Benchmark'):
            parts = line.split()
            if len(parts) >= 2:
                bench_name = parts[0]
                count = parts[1]
                current_block['benchmarks'].append((bench_name, count))
    
    if current_block['pkg']:
        blocks.append(current_block)
        
    return blocks

def find_binary_name(pkg, benchmarks, bench_names):
    candidates = []
    
    # Filter by regex match against the benchmarks found in this block
    for b in benchmarks:
        # Compile regex
        try:
            pattern = re.compile(b['regex'])
            # Check if this pattern matches ANY of the benchmarks in the block
            # This is a weak check because "Benchmark" matches everything.
            matches = False
            for bench_name, _ in bench_names:
                if pattern.search(bench_name):
                    matches = True
                    break
            
            if matches:
                candidates.append(b)
        except re.error:
            pass
            
    if not candidates:
        return None
        
    if len(candidates) == 1:
        return candidates[0]['name']
        
    # Tie-breaker: string similarity with pkg
    best_cand = None
    max_score = -1
    
    pkg_lower = pkg.lower()
    
    for cand in candidates:
        name = cand['name']
        name_parts = name.replace('_', ' ').split()
        score = 0
        for part in name_parts:
            if len(part) > 2 and part.lower() in pkg_lower:
                score += len(part)
        
        # Specific heuristics for known difficult cases
        if name == "aws_jsonutil" and "jsonutil" in pkg_lower:
            score += 100
        if name == "aws_restjson" and "restjson" in pkg_lower:
            score += 100
        if name == "ethereum_corevm" and "core/vm" in pkg_lower:
            score += 100
            
        if score > max_score:
            max_score = score
            best_cand = cand['name']
            
    return best_cand

def main():
    toml_path = 'bent_test/benchmarks-picked.toml'
    result_path = 'bent_test/go-benchmark.result'
    output_path = 'bent_test/run_granular.sh'
    
    benchmarks = parse_toml(toml_path)
    result_blocks = parse_results(result_path)
    
    with open(output_path, 'w') as f:
        f.write("#!/bin/bash\n")
        f.write("# Generated script to run benchmarks with specific counts\n\n")
        f.write('OUTPUT_FILE="${1:-results.txt}"\n')
        f.write('COUNT="${2:-6}"\n\n')
        
        for block in result_blocks:
            pkg = block['pkg']
            bench_items = block['benchmarks']
            
            if not bench_items:
                continue
                
            binary_name = find_binary_name(pkg, benchmarks, bench_items)
            
            if binary_name:
                f.write(f"# Package: {pkg}\n")
                for bench_name, count_str in bench_items:
                    try:
                        count = int(count_str)
                        # Strategy: target = count / 30. 
                        # If target < 30, try target = count / 6.
                        # If that target < 6, keep original count.
                        
                        val1 = count // 30
                        if val1 >= 30:
                            new_count = val1
                        else:
                            val2 = count // 6
                            if val2 >= 6:
                                new_count = val2
                            else:
                                new_count = count
                    except ValueError:
                        # Fallback if count is not an integer (unlikely given previous regex parsing)
                        new_count = count_str

                    # Escape special chars in bench name for regex if necessary
                    # But for go test -bench, providing the exact name anchored usually works
                    # unless it has regex meta chars. '(', ')', '|' might need handling if they appear
                    # in the output name.
                    # Go benchmark output names usually replace / with / and don't output regex chars often
                    # except maybe if subtests are named strangely.
                    # The user example uses direct name.
                    
                    cmd = f"./{binary_name}_RISC-V-Static -test.run=none -test.bench=^{re.escape(bench_name)}$ -test.benchtime={new_count}x -test.count=$COUNT | tee -a \"$OUTPUT_FILE\""
                    f.write(f"{cmd}\n")
                f.write("\n")
            else:
                f.write(f"# Could not identify binary for package: {pkg}\n\n")

    print(f"Generated {output_path}")

if __name__ == '__main__':
    main()

