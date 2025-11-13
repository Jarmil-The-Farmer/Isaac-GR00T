"""Enrich recorded parquet files."""

from argparse import ArgumentParser
from pathlib import Path
from os import scandir
import pandas as pd

if __name__ == "__main__":
    arg_parser = ArgumentParser()
    arg_parser.add_argument("meta_path", type=str, nargs=1, help="Path to root folder of data.")

    args = arg_parser.parse_args()

    data_path = Path(args.meta_path[0]) / "data" / "chunk-000"

    with scandir(data_path) as it:
        for parquet_file_path in it:
            df = pd.read_parquet(parquet_file_path.path)
            df.insert(0, "annotation.human.action.task_description", 0)
            df.insert(0, "annotation.human.validity", 1)
            df.to_parquet(parquet_file_path)
