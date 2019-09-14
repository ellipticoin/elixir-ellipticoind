use serde_cbor::Value;
use vm::Transaction;
use vm::VM;
use vm::{Memory, Storage};
use vm::Changeset;
use vm::Env;
use std::collections::HashMap;

pub fn is_system_contract(transaction: &Transaction) -> bool {
    transaction.contract_address == [0; 32] && transaction.contract_name == "system"
}
use vm::new_module_instance;

pub fn run(
    transaction: &Transaction,
    memory: Memory,
    storage: Storage,
    env: Env,
    ) -> (Changeset, Changeset, (u32, Value)) {
    match transaction.function.as_str() {
        "create_contract" => create_contract(transaction, memory, storage, env),
        _ => (HashMap::new(), HashMap::new(), (0, Value::Null)),
    }
}

pub fn create_contract(
    transaction: &Transaction,
    memory: Memory,
    mut storage: Storage,
    env: Env,
) -> (Changeset, Changeset, (u32, Value)) {
    if let [Value::Text(contract_name), serde_cbor::Value::Bytes(code), serde_cbor::Value::Array(arguments)] =
        &transaction.arguments[..]
    {
        storage.set(vm::namespace(transaction.sender.clone(), contract_name), code.to_vec());
        storage.commit();
        run_constuctor(transaction, memory, storage, env, contract_name, arguments)
    } else {
        (HashMap::new(), HashMap::new(), (0, Value::Null))
    }
}
fn run_constuctor(
    transaction: &Transaction,
    memory: Memory,
    storage: Storage,
    env: Env,
    contract_name: &str,
    arguments: &Vec<Value>,
) -> (Changeset, Changeset, (u32, Value)) {
    let (memory_changeset, storage_changeset, (result, _gas_left)) = Transaction {
        function: "constructor".to_string(),
        arguments: arguments.to_vec(),
        sender: transaction.sender.clone(),
        nonce: transaction.nonce,
        gas_limit: transaction.gas_limit,
        contract_name: contract_name.to_string(),
        contract_address: transaction.sender.clone(),
    }
    .run(
        memory,
        storage,
        env,
    );
    (memory_changeset, storage_changeset, result)
}

pub fn transfer(
    transaction: &Transaction,
    redis: &vm::Client,
    rocksdb: vm::ReadOnlyDB,
    memory_changeset: Changeset,
    storage_changeset: Changeset,
    env: &Env,
    amount: u32,
    from: Vec<u8>,
    to: Vec<u8>,
) -> (Changeset, Changeset, (u32, Value)) {
    let mut memory = Memory::new(redis.get_connection().unwrap(), memory_changeset);
    let mut storage = Storage::new(redis.get_connection().unwrap(), rocksdb, storage_changeset);
    let arguments = vec![
        Value::Bytes(to),
        Value::Integer(amount as i128),
    ];
    let transaction = Transaction {
        contract_name: "BaseToken".to_string(),
        function: "transfer".to_string(),
        nonce: 0,
        gas_limit: transaction.gas_limit,
        contract_address: [0 as u8; 32].to_vec(),
        sender: from.clone(),
        arguments: arguments.clone(),
    };
    let code = storage.get(&vm::namespace(transaction.contract_address.clone(), &transaction.contract_name.clone()));
    let module_instance = new_module_instance(code);
    let mut vm = VM {
        instance: &module_instance,
        memory: &mut memory,
        storage: &mut storage,
        env: &env,
        transaction: &transaction,
        gas: None,
    };
    let result = vm.call("transfer", transaction.arguments.clone()).0;
    (memory.changeset.clone(), storage.changeset.clone(), result)
}
