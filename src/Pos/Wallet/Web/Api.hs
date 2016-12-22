{-# LANGUAGE DataKinds     #-}
{-# LANGUAGE TypeOperators #-}

-- | Servant API for wallet.

module Pos.Wallet.Web.Api
       ( WalletApi
       , walletApi
       ) where

import           Data.Proxy                 (Proxy (Proxy))
import           Servant.API                ((:<|>), (:>), Capture, Get, JSON, Post)

import           Pos.Types                  (Address, Coin, Tx)
import           Pos.Wallet.Web.ClientTypes (CAddress)

-- | Servant API which provides access to wallet.
type WalletApi =
     "api" :> "addresses" :> Get '[JSON] [CAddress]
    :<|>
     "api" :> "balances" :> Get '[JSON] [(CAddress, Coin)]
    :<|>
     "api" :> "send" :> Capture "from" Address :> Capture "to" Address :> Capture "amount" Coin :> Post '[JSON] ()
    :<|>
     "api" :> "history" :> Capture "address" Address :> Get '[JSON] [Tx]
    :<|>
     "api" :> "new_address" :> Post '[JSON] CAddress
    :<|>
    -- FIXME: this should be DELETE method
     "api" :> "delete_address" :> Capture "address" Address :> Post '[JSON] ()

-- | Helper Proxy.
walletApi :: Proxy WalletApi
walletApi = Proxy
