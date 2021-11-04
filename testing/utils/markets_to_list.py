import csv
import sys

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

def get_list(file):
    val_list = csv_to_list(file)
    val_str = ' '.join(val_list)
    # Prints to sequence of strings for an env variable.
    print(val_str)

def test_get_list(name, file):
    val_list = csv_to_list(file)
    print(f'{name} fetched, starts with: {val_list[0:3]} length {len(val_list)}')
    return val_list

def populate_test_markets(items, money):
    # Used by pytest
    money_list = test_get_list('money', money)
    money_list = [int(i) for i in money_list]
    item_list = test_get_list('items', items)
    item_list = [int(i) for i in item_list]
    # Return list of integers.
    return money_list, item_list

if __name__ == "__main__":
    # Used by export_markets.sh
    # Call each file by passing an index.
    # python market_to_list.py 0
    # python market_to_list.py 1

    filename = sys.argv[1]
    get_list(filename)
