import os
import sys

script_dir = os.path.dirname(os.path.abspath(__file__))

build_path = os.path.join(script_dir, 'CppBindings', 'build-release')
sys.path.append(build_path)

import PythonHarmonicModule # type: ignore

import os
import sys
import math
import json
import psutil
import logging
import numpy as np
from functools import partial
from dotenv import load_dotenv
from mp_api.client import MPRester
from pymatgen.analysis.bond_valence import BVAnalyzer
from pymatgen.analysis.local_env import VoronoiNN
from pymatgen.core import Structure
from concurrent.futures import ProcessPoolExecutor
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

def get_cache_path(element, target_min_len, search_cutoff):
    if not os.path.exists("pre_process_cache"):
        os.makedirs("pre_process_cache")
        
    return f"pre_process_cache/cache_{element}_{target_min_len}_{search_cutoff}.npz"

def log_memory_usage(stage_name, num_atoms):
    process = psutil.Process(os.getpid())
    mem_mb = process.memory_info().rss / (1024 ** 2)
    logger = logging.getLogger("ClusterLogger")
    logger.info(f"MEM_CHECK | Stage: {stage_name} | Atoms: {num_atoms} | RAM: {mem_mb:.2f} MB")
    return mem_mb

def get_structure(element, folder="data_cache")->Structure | None:
    if not os.path.exists(folder):
        os.makedirs(folder)
    
    file_path = os.path.join(folder, f"{element}_structure.json")

    if os.path.exists(file_path):
        with open(file_path, "r") as f:
            return Structure.from_dict(json.load(f))

    logger.info("Files not found in data cache, downloading...")
    load_dotenv()
    api_key = os.getenv('MAT_PROJ_KEY')

    if not api_key:
        raise ValueError("Material project key is missing from .env file")
    
    with MPRester(api_key) as mpr:
        docs = mpr.materials.summary.search(material_ids=[element])
        if not docs:
            return None
        
        struct = docs[0].structure
        
        with open(file_path, "w") as f:
            json.dump(struct.as_dict(), f)
            
        return struct
    
def process_chunk(indices, struct, vnn):
    chunk_results = []
    for i in indices:
        info = vnn.get_nn_info(struct, i)
        center = struct[i].coords
        weights = np.array([item['weight'] for item in info], dtype=np.float64)
        neighbors = np.array([item['site'].coords for item in info], dtype=np.float64).flatten()
        chunk_results.append((center, weights, neighbors))
    return chunk_results

def pre_process_paralel(struct, vnn, n_workers=None):
    
    num_sites = len(struct)
    indices = list(range(num_sites))
    
    chunk_size = 500 
    chunks = [indices[i:i + chunk_size] for i in range(0, num_sites, chunk_size)]
    
    all_results = []
    worker_func = partial(process_chunk, struct=struct, vnn=vnn)

    with ProcessPoolExecutor(max_workers=n_workers) as executor:
        for chunk_result in executor.map(worker_func, chunks):
            all_results.extend(chunk_result)

    all_centers, all_weights, all_neighbor_coords = zip(*all_results)
    
    return list(all_centers), list(all_weights), list(all_neighbor_coords)

def get_results(struct, vnn, n_workers, element, target_min_len, search_cutoff, cached=False):
    
    cache_file = get_cache_path(element, target_min_len, search_cutoff)
    if cached:
        if os.path.exists(cache_file):
            logger.info("Using element cache")
            data = np.load(cache_file, allow_pickle=True)
            return list(data['centers']), list(data['weights']), list(data['neighbors'])
    
    all_centers, all_weights, all_neighbor_coords = pre_process_paralel(struct, vnn, n_workers)
    
    np.savez_compressed(
        cache_file, 
        centers=np.array(all_centers), 
        weights=np.array(all_weights, dtype=object), 
        neighbors=np.array(all_neighbor_coords, dtype=object)
    )
    
    return all_centers, all_weights, all_neighbor_coords

@profile  # type: ignore
def main(target_min_len, search_cutoff, element, max_workers=None)->None:
    logger = custom_logger()
    
    struct = get_structure(element)
    
    if not struct:
        raise ValueError("Cannot get specified material")

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
    vnn = VoronoiNN(tol=0.1, allow_pathological=True, cutoff=search_cutoff)
       
    
    # all_centers, all_weights, all_neighbor_coords = pre_process_paralel(struct, vnn, max_workers)
    all_centers, all_weights, all_neighbor_coords = get_results(struct, vnn, max_workers, element, target_min_len, search_cutoff, True)
    
    centers_np = np.array(all_centers)
    
    actual_num_atoms = len(centers_np)
    
    log_memory_usage("Memory usage total", actual_num_atoms)
    logger.info(f"Started cpp module with {actual_num_atoms} atoms")
    
    results = PythonHarmonicModule.analyze_atoms(centers_np, all_weights, all_neighbor_coords, actual_num_atoms)
    
    logger.info("Cpp module ended. Starting dump")
                
            
    with open("cpp_local_order.info", "w") as file:
        file.write(f"Order Parameter Types: {types_to_check}\n")
        if False:
            for i, data in enumerate(results):
                file.write(f"Site {i}: {data}\n")
            
    logger.info("Dump ended")

            

if __name__ == "__main__":
    logger = custom_logger()
    
    test_type = 1
    max_workers = 2
    
    if len(sys.argv) > 1:
        test_type = int(sys.argv[1])
    
    if len(sys.argv) > 2:
        max_workers = int(sys.argv[2])
    
    logger.info(f"Config: Test Type {test_type}, Workers: {max_workers}")

    if test_type == 1:
        logger.info("Started easy test")
        main(25, 4, "mp-149", max_workers)
    elif test_type == 2:
        logger.info("Started Hard test")
        main(50, 10, "mp-1960", max_workers)
    elif test_type == 3:
        logger.info("Started Cluster test")
        main(100, 20, "mp-1188310", max_workers)
    else:
        logger.info("Started Ultra Cluster Test")
        main(1000, 30, "mp-1188310", max_workers)