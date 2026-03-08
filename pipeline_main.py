import os
import sys

script_dir = os.path.dirname(os.path.abspath(__file__))

build_path = os.path.join(script_dir, 'CppBindings', 'build-release')
sys.path.append(build_path)

import PythonHarmonicModule # type: ignore


import os
import sys
import math
import logging
import numpy as np
from dotenv import load_dotenv
from mp_api.client import MPRester
from pymatgen.analysis.local_env import CrystalNN
from pymatgen.analysis.bond_valence import BVAnalyzer
from pymatgen.analysis.local_env import LocalStructOrderParams
from pymatgen.analysis.local_env import VoronoiNN
from pymatgen.core import Structure
import builtins
#cool hack
if 'profile' not in builtins.__dict__:
    def profile(func):
        return func
    
    
import warnings
warnings.filterwarnings("ignore", message="No oxidation states specified on sites!")
warnings.filterwarnings("ignore", message="CrystalNN: cannot locate an appropriate radius")

def custom_logger():
    logger = logging.getLogger("ClusterLogger")
    
    if not logger.handlers:
        logger.setLevel(logging.INFO)

        file_handler = logging.FileHandler("cluster_job.log")
        file_handler.setFormatter(logging.Formatter('%(asctime)s [%(levelname)s] %(message)s'))
        
        console_handler = logging.StreamHandler(sys.stdout)
        console_handler.setLevel(logging.ERROR) 
        console_handler.setFormatter(logging.Formatter('[!] %(levelname)s: %(message)s'))

        logger.addHandler(file_handler)
        logger.addHandler(console_handler)
    
    return logger

    
@profile  # type: ignore
def main(target_min_len, search_cutoff, element)->None:
    logger = custom_logger()
    load_dotenv()
    api_key = os.getenv('MAT_PROJ_KEY')

    if not api_key:
        raise ValueError("Material project key is missing from .env file")

    with MPRester(api_key) as mpr:
        docs = mpr.materials.summary.search(material_ids=[element])
        struct: Structure = docs[0].structure

    bva = BVAnalyzer()
    try:
        valences = bva.get_valences(struct)
        with open("valences.info", "w") as file:
            for v in valences:
                if isinstance(v, int):
                    file.write(f"{v}\n")
                elif isinstance(v, list):
                    line = " ".join(map(str, v))
                    file.write(f"{line}\n")
            file.close()
    except:
        logger.error("Symmetry too broken for standard BVA, ignoring")
        
    abc = struct.lattice.abc # In Armstrongs btw | Me when my arm is strong 😎

    factors = [math.ceil(target_min_len / length) for length in abc]

    logger.info(f"Factors: {factors[0]:.2f}, {factors[1]:.2f}, {factors[2]:.2f}")
    logger.info(f"Total atoms to analyze: {len(struct)}")

    struct.make_supercell(factors)
    
    types_to_check = ["tet", "oct", "bcc", "sq_pyr"]
    lsop = LocalStructOrderParams(types_to_check)

    vnn = VoronoiNN(tol=0.1, allow_pathological=True, cutoff=search_cutoff)
    all_info = []
    cpp_geometric_data = []
    for i in range(len(struct)):
        
        info = vnn.get_nn_info(struct, i)
        all_info.append(info)
        neigh_indices = [item['site_index'] for item in info]
        
        coords = struct[i].coords # type: ignore
        # order_params = lsop.get_order_parameters(struct, i, indices_neighs=neigh_indices)
        all_weights = np.array([item['weight'] for item in info], dtype=np.float64)
        all_coords = np.array([item['site'].coords for item in info], dtype=np.float64)

        cpp_order_params = PythonHarmonicModule.analyze_atoms(coords, all_weights, all_coords, len(info))
        cpp_geometric_data.append(cpp_order_params)
                            
        if i % 100 == 0:
            logger.info(f"Processed {i}/{len(struct)} atoms")
            
        with open("cpp_local_order.info", "w") as file:
            file.write(f"Order Parameter Types: {types_to_check}\n")
            for i, data in enumerate(cpp_geometric_data):
                file.write(f"Site {i}: {data}\n")

            
# 10 - 15 min => 50
# 2-5 hours => 80
# TARGET_MIN_LENGTH = 20.0 
if __name__ == "__main__":
    logger = custom_logger()
    if len(sys.argv) == 1 or sys.argv[1] == "1": 
        logger.info("Started easy test")
        main(25, 4, "mp-149")
    elif sys.argv[1] == "2":
        logger.info("Started Hard test")
        main(50, 10, "mp-1960")
    else:
        logger.info("Started Cluster test")
        main(100, 20, "mp-1188310")