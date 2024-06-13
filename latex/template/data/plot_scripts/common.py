import glob as glob
import matplotlib.figure as pltfig
import matplotlib.pyplot as plt
import re

from typing import Union

def plot_dir_latest() -> str:
    dir_latest = "../plots"
    return dir_latest


class PlotSaver:
    @staticmethod
    def save(fig: pltfig.Figure, trpath: Union[str, None], fpath: Union[str, None], fname: str):
        PlotSaver._save_to_fpath(
            fig, trpath, fpath, fname, ext="pdf", show=False)

    @staticmethod
    def _save_to_fpath(
        fig: pltfig.Figure, trpath: Union[str, None], fpath: Union[str, None], fname: str, ext="png", show=True
    ):
        trpref = ""
        if trpath is not None:
            if "/" in trpath:
                trpref = trpath.split("/")[-1] + "_"
            elif len(trpath) > 0:
                trpref = f"{trpath}_"

        if fpath is None:
            fpath = plot_dir_latest()

        full_path = f"{fpath}/{trpref}{fname}.{ext}"

        if show:
            print(f"[PlotSaver] Displaying figure\n")
            fig.show()
        else:
            print(f"[PlotSaver] Writing to {full_path}\n")
            fig.savefig(full_path, dpi=300)

