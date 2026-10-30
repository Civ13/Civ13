"""Run the existing held bounded synthetic encoder check on the admitted job."""
import argparse
import json
from pathlib import Path
from encoder_proof import run

if __name__ == '__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--root',type=Path,required=True);args=parser.parse_args()
    print(json.dumps(run(args.root),sort_keys=True))
