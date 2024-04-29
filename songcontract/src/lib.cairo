// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts for Cairo 0.12.0

#[starknet::interface]
pub trait ISongContract<TContractState> {
    fn increase_balance(ref self: TContractState, user: starknet::ContractAddress, amount: u256);
    fn update_income(ref self: TContractState, income: u256);
    fn owner_withdraw(ref self: TContractState, amount: u256);
    fn claim(ref self: TContractState, user: starknet::ContractAddress);
    fn get_user_tokens_data(self: @TContractState, user: starknet::ContractAddress) -> (u256, u256);
    fn get_free_token_balance(self: @TContractState) -> u256;
    fn get_tokenholders_number(self: @TContractState) -> u32;
}

#[starknet::contract]
mod SongContract {
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use openzeppelin::token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin::token::erc20::interface;
    use alexandria_storage::list::{List, ListTrait};
    use starknet::{ContractAddress, ClassHash, get_caller_address, contract_address_const};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20CamelOnlyImpl = ERC20Component::ERC20CamelOnlyImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        tokenholders: List<ContractAddress>,
        earnings: LegacyMap<ContractAddress, u256>
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        ERC20Event: ERC20Component::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.erc20.initializer("Dealer", "MD-Dealer");
        self.ownable.initializer(owner);
        self.erc20._mint(owner, 100000);
    }
    
    #[abi(embed_v0)]
    impl ERC20MetadataImpl of interface::IERC20Metadata<ContractState> {
        fn name(self: @ContractState) -> ByteArray {
            self.erc20.name()
        }

        fn symbol(self: @ContractState) -> ByteArray {
            self.erc20.symbol()
        }

        fn decimals(self: @ContractState) -> u8 {
            1
        }
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable._upgrade(new_class_hash);
        }
    }

    #[abi(embed_v0)]
    impl SongContract of super::ISongContract<ContractState> {
        fn increase_balance(ref self: ContractState, user: ContractAddress, amount: u256) {
            self.ownable.assert_only_owner();
            self.erc20.transfer(user, amount);
        }

        fn update_income(ref self: ContractState, income: u256) {
            self.ownable.assert_only_owner();

            let mut incomePerToken = income / (self.erc20.total_supply() - self.erc20.balance_of(self.ownable.owner()));
            let mut index = 0;
            let tokenholder_number = self.get_tokenholders_number();
            let self_snap = @self;

            while index != tokenholder_number {
            	let user = self.tokenholders.read()[index];
                let earning = incomePerToken * self_snap.erc20.balance_of(user);
                let prev_earning = self.earnings.read(user);
                self.earnings.write(user, earning + prev_earning);

                index += 1;
            };
        }

        fn owner_withdraw(ref self: ContractState, amount: u256) {
            self.ownable.assert_only_owner();
            self._transfer_usdt(self.ownable.owner(), amount);
        }

        fn claim(ref self: ContractState, user: starknet::ContractAddress) {
            self.ownable.assert_only_owner();
            self._transfer_usdt(user, self.earnings.read(user));
            self.earnings.write(user, 0);
        }

        fn get_user_tokens_data(self: @ContractState, user: ContractAddress) -> (u256, u256) {
            return (self.erc20.balance_of(user), self.earnings.read(user));
        }

        fn get_free_token_balance(self: @ContractState) -> u256 {
            return self.erc20.balance_of(self.ownable.owner());
        }

        fn get_tokenholders_number(self: @ContractState) -> u32 {
            return self.tokenholders.read().len();
        }
    }
    
    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        fn _transfer_usdt(ref self: ContractState, to: ContractAddress, amount: u256) {
            let usdt_address: ContractAddress = self._get_usdt_address();
            IERC20Dispatcher { contract_address: usdt_address }.transfer(to, amount);
    	}

        fn _get_usdt_address(self: @ContractState) -> ContractAddress {
            contract_address_const::<0x068f5c6a61780768455de69077e07e89787839bf8166decfbf92b645209c0fb8>()
        }
    }
}

