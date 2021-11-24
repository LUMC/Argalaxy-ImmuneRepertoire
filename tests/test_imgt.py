# Copyright (c) 2021 Leiden University Medical Center
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

import os
import shutil
import subprocess
import tempfile
from pathlib import Path
from xml.etree import ElementTree
from xml.etree.ElementTree import Element

import pytest

GIT_ROOT = Path(__file__).parent.parent.absolute()
TEST_DIR = Path(__file__).parent
TEST_DATA_DIR = TEST_DIR / "data"
VALIDATION_DATA_DIR = TEST_DIR / "validation_data"
CONTROL_NWK377_PB_IGHC_MID1_40nt_2 = TEST_DATA_DIR / "CONTROL_NWK377_PB_IGHC_MID1_40nt_2.txz"


def get_container():
    tool = ElementTree.parse(GIT_ROOT / "complete_immunerepertoire.xml").getroot()
    requirements: Element = tool.find("requirements")
    container = requirements.find("container")
    return container.text


@pytest.fixture(scope="module")
def imgt_result():
    temp_dir = Path(tempfile.mkdtemp())
    tool_dir = temp_dir / "imgt"
    shutil.copytree(GIT_ROOT, tool_dir)
    working_dir = temp_dir / "working"
    working_dir.mkdir(parents=True)
    output_dir = temp_dir / "outputs"
    output_dir.mkdir(parents=True)
    wrapper = str(tool_dir / "complete.sh")
    sample = CONTROL_NWK377_PB_IGHC_MID1_40nt_2
    input = f"\"ID1\" {sample} {sample} \"ID2\" {sample}"
    out_files_path = output_dir / "results"
    out_files_path.mkdir(parents=True)
    out_file = out_files_path / "result.html"
    clonaltype = "none"
    gene_selection = dict(species="Homo sapiens functional",
                          locus="TRA")
    filterproductive = "yes"
    clonality_method = "none"
    cmd = [
        "bash",
        wrapper,
        input,
        str(out_file),
        str(out_files_path),
        clonaltype,
        gene_selection["species"],
        gene_selection["locus"],
        filterproductive,
        clonality_method
    ]
    docker_cmd = ["docker", "run", "-v", f"{temp_dir}:{temp_dir}",
                  "-v", f"{sample}:{sample}",
                  "-w", str(working_dir),
                  get_container()] + cmd
    with open(temp_dir / "stderr", "wt") as stderr_file:
        with open(temp_dir / "stdout", "wt") as stdout_file:
            subprocess.run(docker_cmd, cwd=working_dir, stdout=stdout_file,
                           stderr=stderr_file, check=True)
    yield Path(out_files_path)


def test_check_output(imgt_result):
    assert imgt_result.exists()
