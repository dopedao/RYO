package api

// https://voyager.online/api/txns?block=5519&ps=10&p=1

type TransactionReceipt struct {
	BlockID          uint64 `json:"block_id"`
	BlockNumber      uint64 `json:"block_number"`
	Status           string `json:"status"`
	TransactionHash  string `json:"transaction_hash"`
	TransactionIndex uint64 `json:"transaction_index"`
}

type Block struct {
	BlockID             uint64               `json:"block_id"`
	PrevBlockId         uint64               `json:"previous_block_id"`
	SequenceNumber      uint64               `json:"sequence_number"`
	StateRoot           string               `json:"state_root"`
	Status              string               `json:"status"`
	Timestamp           uint64               `json:"timestamp"`
	TransactionReceipts []TransactionReceipt `json:"transaction_receipts"`
	Transactions        []Transaction        `json:"transactions"`
}

// {
//     "block_id": 0,
//     "previous_block_id": -1,
//     "sequence_number": 0,
//     "state_root": "079354de0075c5c1f2a6af40c7dd70a92dc93c68b54ecc327b61c8426fea177c",
//     "status": "PENDING",
//     "timestamp": 105,
//     "transaction_receipts": [
//         {
//             "block_id": 0,
//             "block_number": 0,
//             "execution_resources": {
//                 "builtin_instance_counter": {},
//                 "n_memory_holes": 0,
//                 "n_steps": 0
//             },
//             "l2_to_l1_messages": [],
//             "status": "PENDING",
//             "transaction_hash": "0x602e4b4e9e046d2692af3702fe013fef996df040af335223e7526c9c4fe6fb",
//             "transaction_index": 0
//         },
//         {
//             "block_id": 0,
//             "block_number": 0,
//             "execution_resources": {
//                 "builtin_instance_counter": {
//                     "bitwise_builtin": 0,
//                     "ec_op_builtin": 0,
//                     "ecdsa_builtin": 0,
//                     "output_builtin": 0,
//                     "pedersen_builtin": 0,
//                     "range_check_builtin": 0
//                 },
//                 "n_memory_holes": 0,
//                 "n_steps": 65
//             },
//             "l2_to_l1_messages": [],
//             "status": "PENDING",
//             "transaction_hash": "0x142ca10924ad813764aa8f7ac7c298721708bf531d12d6e5fc4bda3cf9c7904",
//             "transaction_index": 1
//         }
//     ],
//     "transactions": [
//         {
//             "constructor_calldata": [],
//             "contract_address": "0x05a4d278dceae5ff055796f1f59a646f72628730b7d72acb5483062cb1ce82dd",
//             "contract_address_salt": "0x0",
//             "transaction_hash": "0x602e4b4e9e046d2692af3702fe013fef996df040af335223e7526c9c4fe6fb",
//             "type": "DEPLOY"
//         },
//         {
//             "calldata": [
//                 "1234"
//             ],
//             "caller_address": "0x0",
//             "contract_address": "0x05a4d278dceae5ff055796f1f59a646f72628730b7d72acb5483062cb1ce82dd",
//             "entry_point_selector": "0x362398bec32bc0ebb411203221a35a0301193a96f317ebe5e40be9f60d15320",
//             "entry_point_type": "EXTERNAL",
//             "signature": [],
//             "transaction_hash": "0x142ca10924ad813764aa8f7ac7c298721708bf531d12d6e5fc4bda3cf9c7904",
//             "type": "INVOKE_FUNCTION"
//         }
//     ]
// }

type Transaction struct {
	ContractAddress     string `json:"contract_address"`
	ContractAddressSalt string `json:"contract_address_salt"`
	TransactionHash     string `json:"transaction_hash"`
}

type DeployTransaction struct {
	Transaction
	ConstructorCalldata []interface{} `json:"constructor_calldata"`
}

type InvokeTransaction struct {
	Transaction
	Calldata       []interface{} `json:"calldata"`
	CallerAddress  string        `json:"caller_address"`
	EntryPointType string        `json:"entry_point_type"`
}
