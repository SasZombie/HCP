import pandas as pd
import matplotlib.pyplot as plt
import glob
import os

files = glob.glob("results_easy/*.csv")

for file in files:
    plt.figure(figsize=(10, 6))
    
    df = pd.read_csv(file, skipinitialspace=True)
    df.columns = df.columns.str.strip()
    
    filename = os.path.basename(file)

    for cpu in ['DXGA100', 'Haswell']:
        color = 'blue' if cpu == 'DXGA100' else 'red'
        

        first_val = df[cpu].iloc[0]
        second_val = df[cpu].iloc[1]
        

        is_anomaly = first_val > (second_val * 1.5)

        if is_anomaly:

            plt.plot(df['Threads'].iloc[1:], df[cpu].iloc[1:], 'o-', 
                     color=color, label=f"{cpu}")
            
            plt.scatter(df['Threads'].iloc[0], first_val, 
                        color=color, marker='x', s=120, linewidths=2,
                        label=f"{cpu} Anomaly Detected")
        else:
            plt.plot(df['Threads'], df[cpu], 'o-', color=color, label=f"{cpu}")

    plt.title(f'Performance Scaling: {filename}', fontsize=14)
    plt.xlabel('Number of Threads', fontsize=12)
    plt.ylabel('Execution Time (seconds)', fontsize=12)
    
    plt.xticks(df['Threads'].unique())
    
    plt.grid(True, linestyle='--', alpha=0.6)
    plt.legend()
    plt.tight_layout()
    
    plt.show()