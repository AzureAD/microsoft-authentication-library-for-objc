#!/usr/bin/env python3
"""
Script to combine test account logs from multiple Azure DevOps pipeline jobs.
This should be run in a final job after all test jobs have completed.
"""

import os
import sys
import glob
import argparse
from datetime import datetime
from pathlib import Path


def parse_args():
    parser = argparse.ArgumentParser(
        description='Combine test account logs from multiple pipeline jobs'
    )
    parser.add_argument(
        '--input-dir',
        default=None,
        help='Directory containing log files to combine (default: $PIPELINE_WORKSPACE/TestAccountLogs)'
    )
    parser.add_argument(
        '--output-file',
        default='combined_test_account_logs.txt',
        help='Output file name for combined logs (default: combined_test_account_logs.txt)'
    )
    parser.add_argument(
        '--output-dir',
        default=None,
        help='Output directory for combined log (default: current directory)'
    )
    parser.add_argument(
        '--sort-by-time',
        action='store_true',
        help='Sort log entries by timestamp (default: sort by job)'
    )
    return parser.parse_args()


def extract_timestamp(log_line):
    """
    Extract timestamp from log line in format [YYYY-MM-DD HH:MM:SS]
    Returns None if no timestamp found.
    """
    try:
        if log_line.startswith('[') and '] ' in log_line:
            timestamp_str = log_line[1:log_line.index(']')]
            return datetime.strptime(timestamp_str, '%Y-%m-%d %H:%M:%S')
    except (ValueError, IndexError):
        pass
    return None


def combine_logs(input_dir, output_file, sort_by_time=False):
    """
    Combine all test account log files from input_dir into a single output_file.
    
    Args:
        input_dir: Directory containing log files
        output_file: Path to output combined log file
        sort_by_time: If True, sort entries by timestamp; if False, sort by job
    """
    # Find all test account log files (search recursively since
    # DownloadPipelineArtifact places files in subdirectories like
    # TestAccountLogs_<testPlan>/test_logs/test_account_log_*.txt)
    log_files = sorted(glob.glob(os.path.join(input_dir, '**/test_account_log_*.txt'), recursive=True))
    
    # Also check top-level in case files are flat
    if not log_files:
        log_files = sorted(glob.glob(os.path.join(input_dir, 'test_account_log_*.txt')))
    
    if not log_files:
        print(f"No test account log files found in {input_dir}")
        return 0
    
    print(f"Found {len(log_files)} log file(s) to combine:")
    for log_file in log_files:
        print(f"  - {os.path.basename(log_file)}")
    
    all_entries = []
    
    # Read all log files
    for log_file in log_files:
        job_name = os.path.basename(log_file).replace('test_account_log_', '').replace('.txt', '')
        
        try:
            with open(log_file, 'r', encoding='utf-8') as f:
                lines = f.readlines()
                
            if not lines:
                print(f"  WARNING: {os.path.basename(log_file)} is empty")
                continue
            
            print(f"  Read {len(lines)} line(s) from {os.path.basename(log_file)}")
            
            for line in lines:
                timestamp = extract_timestamp(line) if sort_by_time else None
                all_entries.append({
                    'job': job_name,
                    'timestamp': timestamp,
                    'line': line.rstrip('\n')
                })
                
        except Exception as e:
            print(f"  ERROR reading {log_file}: {e}")
            continue
    
    if not all_entries:
        print("No log entries found in any file")
        return 0
    
    # Sort entries
    if sort_by_time:
        # Sort by timestamp, then by job name for entries without timestamps
        all_entries.sort(key=lambda x: (x['timestamp'] if x['timestamp'] else datetime.max, x['job']))
        print(f"\nSorted {len(all_entries)} log entries by timestamp")
    else:
        # Sort by job name (already grouped by file)
        print(f"\nCombined {len(all_entries)} log entries grouped by job")
    
    # Write combined log file
    try:
        with open(output_file, 'w', encoding='utf-8') as f:
            # Write header
            f.write("=" * 80 + "\n")
            f.write("COMBINED TEST ACCOUNT LOGS\n")
            f.write(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write(f"Total Jobs: {len(log_files)}\n")
            f.write(f"Total Entries: {len(all_entries)}\n")
            f.write("=" * 80 + "\n\n")
            
            if sort_by_time:
                # Write all entries sorted by time
                for entry in all_entries:
                    f.write(f"{entry['line']}\n")
            else:
                # Write entries grouped by job with headers
                current_job = None
                for entry in all_entries:
                    if entry['job'] != current_job:
                        if current_job is not None:
                            f.write("\n")
                        current_job = entry['job']
                        f.write("-" * 80 + "\n")
                        f.write(f"Job: {current_job}\n")
                        f.write("-" * 80 + "\n")
                    f.write(f"{entry['line']}\n")
        
        print(f"\nSuccessfully wrote combined log to: {output_file}")
        print(f"File size: {os.path.getsize(output_file)} bytes")
        
        # Print Azure DevOps command to publish the combined log
        if os.environ.get('BUILD_BUILDID'):
            print(f"\n##vso[artifact.upload containerfolder=CombinedLogs;artifactname=CombinedTestAccountLogs]{output_file}")
        
        return len(all_entries)
        
    except Exception as e:
        print(f"ERROR writing combined log: {e}")
        return 0


def main():
    args = parse_args()
    
    # Determine input directory
    input_dir = args.input_dir
    if not input_dir:
        # Try pipeline workspace first
        pipeline_workspace = os.environ.get('PIPELINE_WORKSPACE')
        if pipeline_workspace:
            input_dir = os.path.join(pipeline_workspace, 'TestAccountLogs')
        else:
            input_dir = os.environ.get('TEST_LOG_DIR', '/tmp/test_logs')
    
    # Determine output directory
    output_dir = args.output_dir or os.getcwd()
    output_file = os.path.join(output_dir, args.output_file)
    
    print(f"Input directory: {input_dir}")
    print(f"Output file: {output_file}")
    print(f"Sort by time: {args.sort_by_time}\n")
    
    if not os.path.exists(input_dir):
        print(f"ERROR: Input directory does not exist: {input_dir}")
        return 1
    
    # Ensure output directory exists
    os.makedirs(output_dir, exist_ok=True)
    
    # Combine logs
    entry_count = combine_logs(input_dir, output_file, args.sort_by_time)
    
    if entry_count > 0:
        print(f"\n✓ Successfully combined logs from {entry_count} entries")
        return 0
    else:
        print("\n✗ No logs were combined")
        return 1


if __name__ == '__main__':
    sys.exit(main())
