{-# LANGUAGE DataKinds     #-}
{-# LANGUAGE TypeOperators #-}
module Cardano.Wallet.API.V1 where

import           Cardano.Wallet.API.Types
import qualified Cardano.Wallet.API.V1.Accounts  as Accounts
import qualified Cardano.Wallet.API.V1.Addresses as Addresses
import qualified Cardano.Wallet.API.V1.Wallets   as Wallets

import           Servant

type API = "version"
           :> Summary "Returns the version for this API."
           :> Get '[JSON] WalletVersion
       :<|> Tags '["Accounts"]  :> Accounts.API
       :<|> Tags '["Addresses"] :> Addresses.API
       :<|> Tags '["Wallets"]   :> Wallets.API
