{-# LANGUAGE ConstraintKinds     #-}
{-# LANGUAGE FlexibleContexts    #-}
{-# LANGUAGE RankNTypes          #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE StandaloneDeriving  #-}
{-# LANGUAGE TypeOperators       #-}

-- | Wallet web server.

module Pos.Wallet.Web.Server.Methods
       ( walletApplication
       , walletServer
       ) where

import           Data.List                  (elemIndex, (!!))
import           Formatting                 (int, ords, sformat, (%))
import           Network.Wai                (Application)
import           Servant.API                ((:<|>) ((:<|>)),
                                             FromHttpApiData (parseUrlPiece))
import           Servant.Server             (Handler, ServantErr (errBody), Server,
                                             ServerT, err404, serve)
import           Servant.Utils.Enter        ((:~>) (..), enter)
import           System.Wlog                (logInfo)
import           Universum

import           Pos.Crypto                 (SecretKey, toPublic, whData)
import           Pos.DHT.Model              (dhtAddr, getKnownPeers)
import           Pos.Genesis                (genesisSecretKeys)
import           Pos.Types                  (Address, Coin (Coin), Tx, TxOut (..),
                                             addressF, coinF, decodeTextAddress,
                                             makePubKeyAddress)

import           Pos.Aeson.ClientTypes      ()
import           Pos.Wallet.KeyStorage      (MonadKeys (..), newSecretKey)
import           Pos.Wallet.Tx              (submitTx)
import           Pos.Wallet.WalletMode      (WalletMode, getBalance, getTxHistory)
import           Pos.Wallet.Web.Api         (WalletApi, walletApi)
import           Pos.Wallet.Web.ClientTypes (CAddress, addressToCAddress)
import           Pos.Wallet.Web.State       (MonadWalletWebDB (..), WalletWebDB,
                                             closeState, openState, runWalletWebDB)

----------------------------------------------------------------------------
-- Top level functionality
----------------------------------------------------------------------------

walletApplication
    :: WalletMode ssc m
    => WalletWebDB m (Server WalletApi)
    -> FilePath
    -> m Application
walletApplication server daedalusDbPath = bracket openDB closeDB $ \ws ->
    runWalletWebDB ws server >>= return . serve walletApi
  where openDB = openState True daedalusDbPath
        closeDB = closeState

walletServer
    :: WalletMode ssc m
    => WalletWebDB m (WalletWebDB m :~> Handler)
    -> WalletWebDB m (Server WalletApi)
walletServer nat = flip enter servantHandlers <$> nat

----------------------------------------------------------------------------
-- Handlers
----------------------------------------------------------------------------

type WalletWebMode ssc m
    = ( WalletMode ssc m
      , MonadWalletWebDB m
      )

servantHandlers :: WalletWebMode ssc m => ServerT WalletApi m
servantHandlers = getAddresses :<|> getBalances :<|> send :<|>
                  getHistory :<|> newAddress :<|> deleteAddress

getAddresses :: WalletWebMode ssc m => m [CAddress]
getAddresses = map fst <$> getBalances

getBalances :: WalletWebMode ssc m => m [(CAddress, Coin)]
getBalances = join $ mapM gb <$> myAddresses
  where gb addr = (,) (addressToCAddress addr) <$> getBalance addr

send :: WalletWebMode ssc m => Address -> Address -> Coin -> m ()
send srcAddr dstAddr c = do
    idx <- getAddrIdx srcAddr
    sks <- mySecretKeys
    let sk = sks !! idx
    na <- fmap dhtAddr <$> getKnownPeers
    () <$ submitTx sk na [TxOut dstAddr c]
    logInfo $
        sformat ("Successfully sent "%coinF%" from "%ords%" address to "%addressF)
        c idx dstAddr

getHistory :: WalletWebMode ssc m => Address -> m [Tx]
getHistory addr = map whData <$> getTxHistory addr

newAddress :: WalletWebMode ssc m => m CAddress
newAddress = addressToCAddress . makePubKeyAddress . toPublic <$> newSecretKey

deleteAddress :: WalletWebMode ssc m => Address -> m ()
deleteAddress addr = do
    idx <- getAddrIdx addr
    deleteSecretKey $ fromIntegral idx

----------------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------------

-- TODO: @flyingleafe provide a `debug` flag (in some `WalletContext`?)
-- to disable/enable inclusion of genesis keys
mySecretKeys :: MonadKeys m => m [SecretKey]
mySecretKeys = (genesisSecretKeys ++) <$> getSecretKeys

myAddresses :: MonadKeys m => m [Address]
myAddresses = map (makePubKeyAddress . toPublic) <$> mySecretKeys

getAddrIdx :: WalletWebMode ssc m => Address -> m Int
getAddrIdx addr = elemIndex addr <$> myAddresses >>= maybe notFound return
  where notFound = throwM err404 {
            errBody = encodeUtf8 $
                sformat ("Address "%addressF%" is not found in wallet") $ addr
            }

----------------------------------------------------------------------------
-- Orphan instances
----------------------------------------------------------------------------

deriving instance FromHttpApiData Coin

instance FromHttpApiData Address where
    parseUrlPiece = decodeTextAddress
