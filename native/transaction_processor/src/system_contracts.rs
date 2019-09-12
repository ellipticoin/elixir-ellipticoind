use serde_cbor::Value;
use vm::namespace;
use vm::EllipticoinExternals;
use vm::State;
use vm::Transaction;
use vm::VM;
use vm::{BlockIndex, Memory, Storage};
pub fn is_system_contract(transaction: &Transaction) -> bool {
    transaction.contract_address == [0; 32] && transaction.contract_name == "system"
}
use vm::new_module_instance;

pub fn run(transaction: &Transaction, state: State) -> (u32, Value) {
    match transaction.function.as_str() {
        "create_contract" => create_contract(transaction, state),
        _ => (0, Value::Null),
    }
}

pub fn create_contract(transaction: &Transaction, state: State) -> (u32, Value) {
    if let [Value::Text(contract_name), serde_cbor::Value::Bytes(code), serde_cbor::Value::Array(arguments)] =
        &transaction.arguments[..]
    {
        let block_index = BlockIndex::new(state.redis);
        let mut storage = Storage::new(
            state.rocksdb,
            &block_index,
            state.storage_changeset,
            namespace(transaction.sender.clone(), &contract_name),
        );
        storage.set("_code".as_bytes().to_vec(), code.to_vec());
        storage.commit();
        run_constuctor(transaction, state, contract_name, arguments)
    } else {
        (0, Value::Null)
    }
}
fn run_constuctor(
    transaction: &Transaction,
    state: State,
    contract_name: &str,
    arguments: &Vec<Value>,
) -> (u32, Value) {
    Transaction {
        function: "constructor".to_string(),
        arguments: arguments.to_vec(),
        sender: transaction.sender.clone(),
        nonce: transaction.nonce,
        gas_limit: transaction.gas_limit,
        contract_name: contract_name.to_string(),
        contract_address: transaction.sender.clone(),
    }
    .run(
        state.redis,
        state.rocksdb,
        state.env,
        state.memory_changeset,
        state.storage_changeset,
    )
    .0
}

pub fn charge_gas_fee(transaction: &Transaction, state: State, amount: u32, sender: Vec<u8>) {
    let arguments = vec![
        Value::Bytes(state.env.block_winner.clone()),
        Value::Integer(amount as i128),
    ];
    let transaction = Transaction {
        contract_name: "BaseToken".to_string(),
        function: "transfer".to_string(),
        nonce: 0,
        gas_limit: transaction.gas_limit,
        contract_address: [0 as u8; 32].to_vec(),
        sender: sender.clone(),
        arguments: arguments.clone(),
    };
    let block_index = BlockIndex::new(state.redis);
    let mut memory = Memory::new(
        state.redis,
        &block_index,
        state.memory_changeset,
        transaction.namespace(),
    );
    let mut storage = Storage::new(
        state.rocksdb,
        &block_index,
        state.storage_changeset,
        transaction.namespace(),
    );
    let code = storage.get(&"_code".as_bytes().to_vec());
    let module_instance = new_module_instance(code);
    let mut externals = EllipticoinExternals {
        memory: &mut memory,
        storage: &mut storage,
        env: &state.env,
        transaction: &transaction,
        gas: None,
    };
    let mut vm = VM::new(&module_instance, &mut externals);
    vm.call("transfer", transaction.arguments.clone());
}
