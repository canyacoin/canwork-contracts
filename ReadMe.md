# CanWork Contracts

This repo holds the main Solidity Smart Contracts for CANWork & CANWorkAdmin.

## CANWork

The main contract and the main contract to deal with and consists of a set of smart contracts to facilitate creating Escrow between clients & providers for a given JobId. It also allows for an Arbiter (Admin) to solve a dispute by cancelling a job and specifying final amounts for Client & Provider.

### Escrow

At the heart of CANWork is the Escrow contract that locks up the given amounts between client & provider and it works as follow:

### CANWorkJob

The smart contract responsible for job management, internally in comuunicates with the Escrow for the payments.

- `createJob`
  - Can be called specifying the client, provider and total fees for the job.
  - An escrow will be created depositing a 1% fee immediately into the dApp address.
  - Job status will be `New`
- `completeJob`
  - Can be called by client only.
  - All fees will be transferred to the provider.
  - Job status will be `Completed`
- `cancelJobByProvider`
  - Can be called by provider only.
  - All fees will be transferred to the client.
  - Job status will be `Cancelled`
- `cancelJobByAdmin`
  - Can be called by admin only.
  - Admin specifies how much to be transferred to provider
  - Remining amounts will be refunded to the client based on the equation; refund = total fees - (1% dApp fees + provider amount + arbiter amount)
- `getJob`
  - Will return job details (Id, status, total fees, client and provider)
- `getJobPayments`
  - Will return job escrow details (total fees, dApp fees, provider payment, client payment and arbiter payment)

## Deployment

Each module CANWork and CANAdmin has their on sub-directory where each one of them needs to be deployed separately.

For local environment deployment, a copy of CanYaCoin contract needs to be deployed as well. In production, CanYaCoin is already deployed and holds the CAN tokens.

### Installation

Both CANWork & CANWorkAdmin are upgradable using the ProxyPattern introduced by zeppelin through zeppelin-zos. zos-cli is a helpful CLI to facilitate the deployment of contracts in order to have upgradable contracts. Deployment should go in the following order:

- CanYaCoin contract "only in local & test net if it's not already deployed at the chosen testNet"
- CanWorkAdmin
- CanWork

#### Steps

- `npm i -g zos-cli`
- Make sure you're inside the required directory `canwork-admin` or `canwork-job`
- To compile and deploy the contracts; `zos push --network local`
  - `local` can be replaced with `ropsten` or `mainnet` according to the `truffle-config.js`.
  - This command will read the `/contracts`, compile and generate `.json` files in the `/build` directory.
- To create a proxy for CANWorkAdmin; `zos create CanWorkAdmin --from $owner --init --args $owner1,$owner2,$owner3 --network local`
  - $owner1-3 are the initial 3 owners addresses
  - `zos create` should be used only once after initial deployment. 
- To create a proxy for CANWork; `zos create CanWork --from $owner --init --args $cancoin,$canadmin,$dapp,$oracle --network local`
  - `$cancoin` is the CanYaCoin deployed contract address
  - `$canadmin` is the CanWorkAdmin deployed proxy contract address
  - `$dapp` is the address that will receive the 1% fees.
  - `$oracle` is the address of the price oracle.
- For upgrades we will use `zos update <Contract> --from $owner --network local`
  - For upgrades, make sure to run first `zos push --from $owner --network local`
  - Here, we eliminated the `--init` and `--args` as we don't want to re-initialize the proxy again.
  
#### TestNET & MainNET deployments

For Test/Main net deployments, a pair of Public/Private key are required for the `--from $owner`, this owner used for deployment will need to use his MNemonic secrets or Private key during a deployment, thus it's better to create a new user wallet for this purpose as follows:

- Create a new MetaMask wallet
- MetaMask will display the MNemonics upon creation of the wallet
- Use the first created account as the deployment `owner`
- Enter the MNemonics into the `truffle-configs.js` configuratin section for the chosen network.
- Export necessary params required for the deployment into the terminal session or use them inline as params. Have a look at `./environment/ropsten.sh`

#### Final Note & Additonal Work

Always be careful and double check your input parameters during the deployment and don't call `zos create` twice, otherwise you'll create 2 proxies.

There are some optimization and additonal work required:

- Move the MultiSig.sol code into its own library because it's being used in both CANWorkAdmin & CANWork so there is a space for optimization here.
- To reduce contract sizes; logic can be off-loaded to a libraries as well.
- Zeppelin `Pausable` contract can be integrated into CANWorkAdmin & CANWork to `pause/freeze` operations in case of any leak/bug/danger.
- Test cases need to be added for all contracts. Just needs time :)
