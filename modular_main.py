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

import numpy as np
from scipy.spatial.distance import cdist
from scipy.optimize import linear_sum_assignment

class MinimalLSOP:
    def __init__(self, types):
        self.types = types
        self.templates = {
            "tet": np.array([[1, 1, 1], [1, -1, -1], [-1, 1, -1], [-1, -1, 1]]) / np.sqrt(3),
            "oct": np.array([[1, 0, 0], [-1, 0, 0], [0, 1, 0], [0, -1, 0], [0, 0, 1], [0, 0, -1]]),
            "bcc": np.array([[1, 1, 1], [1, 1, -1], [1, -1, 1], [1, -1, -1],
                             [-1, 1, 1], [-1, 1, -1], [-1, -1, 1], [-1, -1, -1]]) / np.sqrt(3),
            "sq_pyr": np.array([[1,0,0], [-1,0,0], [0,1,0], [0,-1,0], [0,0,1]])
        }

    def get_order_parameters(self, coords, info):

        center = coords
                
        sorted_info = sorted(info, key=lambda x: x.get('weight', 0), reverse=True)
        
        results = {}
        for t in self.types:
            template = self.templates[t]
            n_needed = len(template)
            
            print("N needed = ", n_needed)
            print("Sorted Infor = ", len(sorted_info))
            if len(sorted_info) < n_needed:
                results[t] = 0.0
                continue
                
            neighbor_coords = np.array([item['site'].coords for item in sorted_info[:n_needed]])
            
    
            vecs = neighbor_coords - center
            
            norms = np.linalg.norm(vecs, axis=1)[:, np.newaxis]
            
            normalized_vecs = vecs / (norms + 1e-12)

            if normalized_vecs.ndim == 1:
                normalized_vecs = normalized_vecs.reshape(-1, 3)

            print(normalized_vecs)
            results[t] = self._align_and_score(normalized_vecs, template)
        
        return results
    def _align_and_score(self, coords, template):
        """
        Rotates coords to best fit template using SVD (Kabsch) 
        and matches points using the Hungarian algorithm.
        """
        h_matrix = coords.T @ template
        u, s, vt = np.linalg.svd(h_matrix)
        rotation_matrix = vt.T @ u.T
        
        actual_rotated = coords @ rotation_matrix.T
    
        dist_matrix = cdist(actual_rotated, template, 'sqeuclidean')
        row_ind, col_ind = linear_sum_assignment(dist_matrix)
        
        total_sq_dist = dist_matrix[row_ind, col_ind].sum()
        rmsd = np.sqrt(total_sq_dist / len(template))
        
        return max(0.0, 1.0 - rmsd)

    
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
    
    my_lsop = MinimalLSOP(types_to_check)

    vnn = VoronoiNN(tol=0.1, allow_pathological=True, cutoff=search_cutoff)
    all_info = []
    all_geometric_data = []
    my_all_geometric_data = []
    for i in range(len(struct)):
        
        info = vnn.get_nn_info(struct, i)
        all_info.append(info)
        neigh_indices = [item['site_index'] for item in info]
        
        coords = struct[i].coords # type: ignore
        # order_params = lsop.get_order_parameters(struct, i, indices_neighs=neigh_indices)
        all_weights = np.array([item['weight'] for item in info], dtype=np.float64)
        all_coords = np.array([item['site'].coords for item in info], dtype=np.float64)

        PythonHarmonicModule.analyze_atoms(coords, all_weights, all_coords, len(info))
        
        
        my_order_params = my_lsop.get_order_parameters(coords, info)
        
        exit();
        # all_geometric_data.append(order_params)
        
        my_all_geometric_data.append(my_order_params)
                       
        
        if i % 100 == 0:
            logger.info(f"Processed {i}/{len(struct)} atoms")
            
             
    with open("local_order.info", "w") as file:
        file.write(f"Order Parameter Types: {types_to_check}\n")
        for i, data in enumerate(all_geometric_data):
            file.write(f"Site {i}: {data}\n")
            
    with open("my_local_order.info", "w") as file:
        file.write(f"Order Parameter Types: {types_to_check}\n")
        for i, data in enumerate(my_all_geometric_data):
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