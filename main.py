import os
import sys
import math
import time
import logging
from dotenv import load_dotenv
from mp_api.client import MPRester
from pymatgen.analysis.local_env import CrystalNN
from pymatgen.analysis.bond_valence import BVAnalyzer
from pymatgen.analysis.local_env import LocalStructOrderParams

import warnings
warnings.filterwarnings("ignore", message="No oxidation states specified on sites!")
warnings.filterwarnings("ignore", message="CrystalNN: cannot locate an appropriate radius")

# 10 - 15 min => 50
# 2-5 hours => 80
TARGET_MIN_LENGTH = 20.0 
SEARCH_CUTOFF = 10.0     
    
def setup_custom_logger():
    logger = logging.getLogger("ClusterLogger")
    logger.setLevel(logging.INFO)

    file_handler = logging.FileHandler("cluster_job.log")
    file_handler.setLevel(logging.INFO)
    file_formatter = logging.Formatter('%(asctime)s [%(levelname)s] %(message)s')
    file_handler.setFormatter(file_formatter)

    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(logging.ERROR) 
    console_formatter = logging.Formatter('[!] %(levelname)s: %(message)s')
    console_handler.setFormatter(console_formatter)


    logger.addHandler(file_handler)
    logger.addHandler(console_handler)
    
    return logger

def main()->None:
    logger = setup_custom_logger()
    load_dotenv()
    api_key = os.getenv('MAT_PROJ_KEY')
    
    with MPRester(api_key) as mpr:

        #Easy scenario -> 30 secs
        docs = mpr.materials.summary.search(material_ids=["mp-149"])
        #Hard scenario -> 2 hours+ 
        # docs = mpr.materials.summary.search(material_ids=["mp-1188310"])
        struct = docs[0].structure

    abc = struct.lattice.abc # In Armstrongs btw | Me when my arm is strong 😎

    factors = [math.ceil(TARGET_MIN_LENGTH / length) for length in abc]

    logger.info(f"Factors: {factors[0]:.2f}, {factors[1]:.2f}, {factors[2]:.2f}")
    logger.info(f"Total atoms to analyze: {len(struct)}")

    struct.make_supercell(factors)
    nn = CrystalNN(weighted_cn=True, search_cutoff=10)
    
    types_to_check = ["tet", "oct", "bcc", "sq_pyr"]
    lsop = LocalStructOrderParams(types_to_check)

    all_info = []
    all_geometric_data = []
    for i in range(len(struct)):
        
        info = nn.get_nn_info(struct, i)
        all_info.append(info)
        
        order_params = lsop.get_order_parameters(struct, i)
        all_geometric_data.append(order_params)
        
        if i % 100 == 0:
            logger.info(f"Processed {i}/{len(struct)} atoms")
            
    
    with open("local_order.info", "w") as file:
        file.write(f"Order Parameter Types: {types_to_check}\n")
        for i, data in enumerate(all_geometric_data):
            file.write(f"Site {i}: {data}\n")
            
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
        logger.error("Symmetry too broken for standard BVA, proceeding...")


if __name__ == "__main__":
    main()
    