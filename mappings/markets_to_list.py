import csv
import sys

files = [
    'mappings/initial_markets_money.csv',
    'mappings/initial_markets_item.csv'
]

def csv_to_list(file):
    with open(file, mode='r') as csv_file:
        csv_reader = csv.reader(csv_file, delimiter=',')
        list = []
        for r_idx, row in enumerate(csv_reader):
            if r_idx == 0:
                continue
            for c_idx, col in enumerate(row):
                if c_idx == 0:
                    continue
                list.append(col)
        return list

def get_list(name, file):
    val_list = csv_to_list(file)
    #print(f'{name} fetched, starts with: {val_list[0:3]} length {len(val_list)}')
    val_str = ' '.join(val_list)
    print(val_str)

if __name__ == "__main__":
    # Used by export_markets.sh
    # Call each file by passing an index.
    # python market_to_list.py 0
    # python market_to_list.py 1

    filename = files[int(sys.argv[1])]
    get_list(filename, filename)
