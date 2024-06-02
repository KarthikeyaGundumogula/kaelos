import { Contract, BrowserProvider } from "ethers";
import { CollateralInterface, KelCoinTeller,AssetWarehouse,BSCLinkToken } from "./Addresses";
import { CollateralInterfaceABI, KelCoinTellerABI, GameAssetWarehouseABI,LinkTokenABI } from "./ABIS";

const getSigner = async () => {
  const provider = new BrowserProvider(window.ethereum);
  const signer = await provider.getSigner();
  return signer;
};

export const getCollateralInterFace = async () => {
  const signer = await getSigner();
  const contract = new Contract(
    CollateralInterface,
    CollateralInterfaceABI,
    signer
  );
  return contract;
};

export const getKelCoinTeller = async () => {
  const signer = await getSigner();
  const contract = new Contract(KelCoinTeller, KelCoinTellerABI, signer);
  return contract;
};

export const getGameAssetWarehouse = async () => {
  const signer = await getSigner();
  const contract = new Contract(AssetWarehouse, GameAssetWarehouseABI, signer);
  return contract;
};

export const getLinkToken = async () => {
  const signer = await getSigner();
  const contract = new Contract(BSCLinkToken, LinkTokenABI, signer);
  return contract;
}