// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts for Cairo 0.12.0

#[starknet::interface]
pub trait IBuyerContract<TState> {
    fn buy(ref self: TState, amount: u256, song: starknet::ContractAddress);
    fn change_price(ref self: TState, song: starknet::ContractAddress, new_price: u256);
    fn change_treasury(ref self: TState, new_address: starknet::ContractAddress);
    fn get_price(self: @TState, song: starknet::ContractAddress) -> u256;
    fn get_treasury(self: @TState) -> starknet::ContractAddress;
}

#[starknet::contract]
mod BuyerContract {
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::{ContractAddress, ClassHash, get_caller_address, contract_address_const};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);    

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;

    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        prices: LegacyMap<ContractAddress, u256>,
        treasury: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        TreasuryChanged: TreasuryChanged,
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    struct TreasuryChanged {
        #[key]
        previous_treasury: ContractAddress,
        #[key]
        new_treasury: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, treasury: ContractAddress) {
        self.ownable.initializer(owner);
        self.treasury.write(treasury);
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable._upgrade(new_class_hash);
        }
    }

    #[abi(embed_v0)]
    impl BuyerContract of super::IBuyerContract<ContractState> {
        fn buy(ref self: ContractState, amount: u256, song: ContractAddress) {
            let price = self.prices.read(song);
            assert(price > 0, 'Wrong song address');

	        let caller = get_caller_address();
            let to_pay = price * amount;            
            self._transfer_from_usdt(caller, self.treasury.read(), to_pay);

            IERC20Dispatcher { contract_address: song }.transfer_from(self.ownable.owner(), caller, amount);
        }

        fn change_price(ref self: ContractState, song: ContractAddress, new_price: u256) {
            self.ownable.assert_only_owner();
            self.prices.write(song, new_price);
        }

        fn change_treasury(ref self: ContractState, new_address: ContractAddress) {
            self.ownable.assert_only_owner();
            let previous_address = self.treasury.read();
            self.treasury.write(new_address);
            self.emit(
                TreasuryChanged {
                    previous_treasury: previous_address, 
                    new_treasury: new_address
                }
            );
        }

        fn get_price(self: @ContractState, song: ContractAddress) -> u256 {
            self.prices.read(song)
        }

        fn get_treasury(self: @ContractState) -> ContractAddress {
            self.treasury.read()
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _transfer_from_usdt(ref self: ContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256) {
            let usdt_address: ContractAddress = self._get_usdt_address();
            IERC20Dispatcher { contract_address: usdt_address }.transfer_from(sender, recipient, amount);
    	}

        fn _get_usdt_address(self: @ContractState) -> ContractAddress {
            contract_address_const::<0x068f5c6a61780768455de69077e07e89787839bf8166decfbf92b645209c0fb8>()
        }
    }
}

