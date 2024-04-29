#[starknet::interface]
pub trait IBaseContract<TContractState> {
    fn sign_agreement(ref self: TContractState, user: starknet::ContractAddress);
    fn has_agreement(self: @TContractState, user: starknet::ContractAddress) -> bool;
}

#[starknet::contract]
mod BaseContract {
    use openzeppelin::access::ownable::OwnableComponent;
    use starknet::ContractAddress;
    use starknet::get_caller_address;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;

    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        users: LegacyMap<ContractAddress, bool>
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.ownable.initializer(owner);
    }

    #[abi(embed_v0)]
    impl SimpleCounter of super::IBaseContract<ContractState> {
        fn sign_agreement(ref self: ContractState, user: ContractAddress) {
            self.ownable.assert_only_owner();
            self.users.write(user, true);
        }

        fn has_agreement(self: @ContractState, user: ContractAddress) -> bool {
            return self.users.read(user);
        }
    }
}
