import { expect } from "chai"
import {ethers, getNamedAccounts} from "hardhat"
import {
    FeeDistributor__factory,
    FeeDistributorFactory__factory,
    FeeDistributor,
    FeeDistributorFactory, MockERC20__factory
} from "../typechain-types"
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"

describe("FeeDistributor", function () {

    // P2P should get 30% (subject to chioce at deploy time)
    const servicePercent =  30;

    // client should get 70% (subject to chioce at deploy time)
    const clientPercent = 100 - servicePercent;

    let deployerSigner: SignerWithAddress
    let ownerSigner: SignerWithAddress
    let operatorSigner: SignerWithAddress
    let nobodySigner: SignerWithAddress

    let deployerFactory: FeeDistributor__factory
    let ownerFactory: FeeDistributor__factory
    let operatorFactory: FeeDistributor__factory
    let nobodyFactory: FeeDistributor__factory

    let feeDistributorFactory: FeeDistributorFactory

    let deployer: string
    let owner: string
    let operator: string
    let nobody : string
    let serviceAddress: string

    before(async () => {
        const namedAccounts = await getNamedAccounts()

        deployer = namedAccounts.deployer
        owner = namedAccounts.owner
        operator = namedAccounts.operator
        nobody = namedAccounts.nobody
        serviceAddress = namedAccounts.serviceAddress

        deployerSigner = await ethers.getSigner(deployer)
        ownerSigner = await ethers.getSigner(owner)
        operatorSigner = await ethers.getSigner(operator)
        nobodySigner = await ethers.getSigner(nobody)

        deployerFactory = new FeeDistributor__factory(deployerSigner)
        ownerFactory = new FeeDistributor__factory(ownerSigner)
        operatorFactory = new FeeDistributor__factory(operatorSigner)
        nobodyFactory = new FeeDistributor__factory(nobodySigner)

        // deploy factory contract
        const factoryFactory = new FeeDistributorFactory__factory(deployerSigner)
        feeDistributorFactory = await factoryFactory.deploy({gasLimit: 3000000})
    })

    it("should not be created with incorrect factory", async function () {
        const factory = new FeeDistributor__factory(deployerSigner)

        await expect(factory.deploy(
            nobody,
            serviceAddress,
            servicePercent,
            {gasLimit: 3000000}
        )).to.be.revertedWith(
            `FeeDistributor__NotFactory("${nobody}")`
        )
    })

    it("should not be created with zero serviceAddress", async function () {
        const factory = new FeeDistributor__factory(deployerSigner)

        await expect(factory.deploy(
            feeDistributorFactory.address,
            ethers.constants.AddressZero,
            servicePercent,
            {gasLimit: 1000000}
        )).to.be.revertedWith(
            `FeeDistributor__ZeroAddressService`
        )
    })

    it("should not be created with servicePercent outside [0, 100]", async function () {
        const factory = new FeeDistributor__factory(deployerSigner)

        await expect(factory.deploy(
            feeDistributorFactory.address,
            serviceAddress,
            101,
            {gasLimit: 3000000}
        )).to.be.revertedWith(
            `FeeDistributor__InvalidServicePercent`
        )

        await expect(factory.deploy(
            feeDistributorFactory.address,
            serviceAddress,
            -1,
            {gasLimit: 3000000}
        )).to.throw
    })

    it("initialize should only be called by factory", async function () {
        const factory = new FeeDistributor__factory(deployerSigner)

        const feeDistributor = await factory.deploy(
            feeDistributorFactory.address,
            serviceAddress,
            servicePercent,
            {gasLimit: 3000000}
        )

        await expect(feeDistributor.initialize(
            nobody,{gasLimit: 1000000}
        )).to.be.revertedWith(
            `FeeDistributor__NotFactoryCalled`
        )
    })

    it("deployer should get ownership", async function () {
        const factory = new FeeDistributor__factory(deployerSigner)

        const feeDistributor = await factory.deploy(
            feeDistributorFactory.address,
            serviceAddress,
            servicePercent,
            {gasLimit: 3000000}
        )

        const feeDistributorOwner = await feeDistributor.owner()
        expect(feeDistributorOwner).to.be.equal(deployerSigner.address)
    })

    it("cannot renounce ownership", async function () {
        const factory = new FeeDistributor__factory(deployerSigner)

        const feeDistributor = await factory.deploy(
            feeDistributorFactory.address,
            serviceAddress,
            servicePercent,
            {gasLimit: 3000000}
        )

        await feeDistributor.renounceOwnership()

        const feeDistributorOwner = await feeDistributor.owner()
        expect(feeDistributorOwner).to.be.equal(deployerSigner.address)
    })

    it("the owner of the reference instance should become the owner of a client instance", async function () {
        // deoply factory
        const deployerSignerFactory = new FeeDistributor__factory(deployerSigner)

        // deoply reference instance
        const feeDistributorReferenceInstance = await deployerSignerFactory.deploy(
            feeDistributorFactory.address,
            serviceAddress,
            servicePercent,
            { gasLimit: 3000000 }
        )

        // set reference instance
        await feeDistributorFactory.setReferenceInstance(feeDistributorReferenceInstance.address)

        // become an operator to create a client instance
        await feeDistributorFactory.transferOperator(deployerSigner.address)

        const clientAddress = "0x0000000000000000000000000000000000C0FFEE"
        // create client instance
        const createFeeDistributorTx = await feeDistributorFactory.createFeeDistributor(clientAddress)
        const createFeeDistributorTxReceipt = await createFeeDistributorTx.wait();
        const event = createFeeDistributorTxReceipt?.events?.find(event => event.event === 'FeeDistributorCreated');
        if (!event) {
            throw Error('No FeeDistributorCreated found')
        }
        // retrieve client instance address from event
        const newFeeDistributorAddrress = event.args?._newFeeDistributorAddrress

        const feeDistributorSignedByDeployer = deployerSignerFactory.attach(newFeeDistributorAddrress)

        const clientInstanceOwner = await feeDistributorSignedByDeployer.owner()
        expect(clientInstanceOwner).to.be.equal(deployerSigner.address)
    })

    it("only owner can recover tokens", async function () {
        // deoply factory
        const deployerSignerFactory = new FeeDistributor__factory(deployerSigner)

        // deoply reference instance
        const feeDistributorReferenceInstance = await deployerSignerFactory.deploy(
            feeDistributorFactory.address,
            serviceAddress,
            servicePercent,
            { gasLimit: 3000000 }
        )

        // set reference instance
        await feeDistributorFactory.setReferenceInstance(feeDistributorReferenceInstance.address)

        // become an operator to create a client instance
        await feeDistributorFactory.transferOperator(deployerSigner.address)

        const clientAddress = "0x0000000000000000000000000000000000C0FFEE"
        // create client instance
        const createFeeDistributorTx = await feeDistributorFactory.createFeeDistributor(clientAddress)
        const createFeeDistributorTxReceipt = await createFeeDistributorTx.wait();
        const event = createFeeDistributorTxReceipt?.events?.find(event => event.event === 'FeeDistributorCreated');
        if (!event) {
            throw Error('No FeeDistributorCreated found')
        }
        // retrieve client instance address from event
        const newFeeDistributorAddrress = event.args?._newFeeDistributorAddrress;

        const mockERC20Factory = new MockERC20__factory(deployerSigner)
        const erc20Supply = ethers.utils.parseEther('100')
        // deploy mock ERC20
        const erc20 = await mockERC20Factory.deploy(erc20Supply)
        // transfer mock ERC20 tokens to client instance
        await erc20.transfer(newFeeDistributorAddrress, erc20Supply)

        const feeDistributorSignedByAssetOwner = ownerFactory.attach(newFeeDistributorAddrress)

        await expect(feeDistributorSignedByAssetOwner.transferERC20(erc20.address, nobody, erc20Supply))
            .to.be.revertedWith(
            `Ownable: caller is not the owner`
            )

        await feeDistributorFactory.transferOwnership(owner)

        await feeDistributorSignedByAssetOwner.transferERC20(erc20.address, nobody, erc20Supply)
        const recipientErc20Balance = await erc20.balanceOf(nobody)

        expect(recipientErc20Balance).to.be.equal(erc20Supply)
    })
})
