module Test.Pos.Wallet.Web.Methods.LogicSpec
       ( spec
       ) where

import           Universum

import           Test.Hspec                   (Spec, describe)
import           Test.Hspec.QuickCheck        (prop)

import           Pos.Launcher                 (HasConfigurations)
import           Pos.Wallet.Web.Methods.Logic (getAccounts, getWallets)

import           Test.Pos.Util                (stopProperty, withDefConfigurations)
import           Test.Pos.Wallet.Web.Mode     (WalletProperty)

spec :: Spec
spec = withDefConfigurations $ describe "Pos.Wallet.Web.Methods" $ do
    prop emptyWalletOnStarts emptyWallet
  where
    emptyWalletOnStarts = "wallet must be empty on start"

emptyWallet :: HasConfigurations => WalletProperty ()
emptyWallet = do
    wallets <- lift getWallets
    unless (null wallets) $
        stopProperty "Wallets aren't empty"
    accounts <- lift $ getAccounts Nothing
    unless (null accounts) $
        stopProperty "Accounts aren't empty"
