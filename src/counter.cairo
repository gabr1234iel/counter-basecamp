// Kill switch sepolia contract: 0x05f7151ea24624e12dde7e1307f9048073196644aa54d74a9c579a257214b542

#[starknet::interface]
trait ICounter<ContractState> {
    fn get_counter(self: @ContractState) -> u32;
    fn increase_counter(ref self: ContractState);
}

#[starknet::contract]
pub mod counter_contract {

    use core::starknet::ContractAddress;
    use kill_switch::{IKillSwitchDispatcher, IKillSwitchDispatcherTrait};
    use openzeppelin::access::ownable::OwnableComponent;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    // embedding the Ownable component's logic
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;

    // embedding the Ownable component's internal logic
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        counter: u32,
        kill_switch: IKillSwitchDispatcher,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        CounterIncreased: CounterIncreased,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }
    #[derive(Drop, starknet::Event)]
    struct CounterIncreased {
        #[key]
        value: u32,
    }
        
    #[constructor]
    fn constructor(ref self: ContractState, initial_value: u32, kill_switch: ContractAddress, initial_owner: ContractAddress) {
        self.counter.write(initial_value);
        self.kill_switch.write(IKillSwitchDispatcher { contract_address: kill_switch });
        self.ownable.initializer(initial_owner);
    }

    #[abi(embed_v0)]
    impl CounterImpl of super::ICounter<ContractState>{
        fn get_counter(self: @ContractState) -> u32 {
            self.counter.read()
        }

        fn increase_counter(ref self: ContractState) {
            self.ownable.assert_only_owner();
            let kill_switch = self.kill_switch.read();
            assert!(!kill_switch.is_active(), "Kill Switch is active");
            self.counter.write(self.counter.read() + 1);
            self.emit( CounterIncreased{value: self.counter.read()});
        }
    }
    
}