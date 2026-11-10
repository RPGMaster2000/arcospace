"""Validate complete, disjoint CI shards against source discovery, then report timing."""
import argparse
import json
from pathlib import Path
from regression_support import markdown, select_shard
from run_regressions import discover
from run_rendered_regressions import SUITES


def validate(summaries, suite, expected, count=2):
    if len(summaries) != count:
        raise ValueError(f'{suite}: expected {count} summaries, got {len(summaries)}')
    indices = set()
    observed = []
    for summary in summaries:
        index = summary['shard_index']
        if summary['suite'] != suite or summary['shard_count'] != count or index in indices:
            raise ValueError('Wrong suite, duplicate shard or shard count')
        indices.add(index)
        selected = select_shard(expected, suite, index, count)
        if summary.get('focused') or not summary.get('complete') or set(summary['selected']) != set(selected) or len(summary['selected']) != len(selected):
            raise ValueError('Incomplete or unexpected shard selection')
        runs = summary['runs']
        names = [run['name'] for run in runs if run['name'] != 'import']
        if sorted(names) != sorted(selected) or any(run['status'] != 'passed' for run in runs):
            raise ValueError('Missing, duplicate or failed test result')
        if any(run.get('test_completed') is not True for run in runs if run['name'] != 'import'):
            raise ValueError('Missing test completion evidence')
        observed.extend(names)
    if indices != set(range(1, count + 1)) or sorted(observed) != sorted(expected):
        raise ValueError('Shards do not cover the suite exactly once')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--suite', choices=['headless', *SUITES], required=True)
    parser.add_argument('--results', type=Path, required=True)
    args = parser.parse_args()
    project = Path(__file__).resolve().parents[1]
    expected = [p.stem for p in discover(project)] if args.suite == 'headless' else list(SUITES[args.suite])
    summaries = [json.loads(p.read_text()) for p in sorted(args.results.rglob('summary.json'))]
    validate(summaries, args.suite, expected)
    print(f'Validated {len(expected)} tests exactly once across {len(summaries)} shards.\n')
    for summary in summaries:
        print(markdown(summary))


if __name__ == '__main__':
    main()
