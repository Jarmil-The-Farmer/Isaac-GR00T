"""Generate `modality.json` from the recorded data"""

from argparse import ArgumentParser
import json

# For now it is a static definition with hardcoded action task.
_modality_template = {
    "state": {
        "left_arm": {"start": 0, "end": 7},
        "right_arm": {"start": 7, "end": 14},
        "left_hand": {"start": 14, "end": 20},
        "right_hand": {"start": 20, "end": 26},
    },
    "action": {
        "left_arm": {"start": 0, "end": 7},
        "right_arm": {"start": 7, "end": 14},
        "left_hand": {"start": 14, "end": 20},
        "right_hand": {"start": 20, "end": 26},
    },
    "video": {"ego_view": {"original_key": "observation.images.cam_high"}},
}

if __name__ == "__main__":
    arg_parser = ArgumentParser()
    arg_parser.add_argument("meta_path", type=str, nargs=1, help="Path to `meta` folder of the dataset where `modality.json` will be saved.")

    args = arg_parser.parse_args()

    with open(f"{args.meta_path[0]}/modality.json", "w") as f:
        json.dump(_modality_template, f)
