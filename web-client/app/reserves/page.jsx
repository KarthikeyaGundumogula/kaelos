"use client";
import React, { useState } from "react";
import {
  Box,
  Flex,
  Input,
  Button,
  HStack,
  Text,
  Center,
  Heading,
} from "@chakra-ui/react";
import Header from "@/components/Home/Header";
import { getCollateralInterFace, getLinkToken } from "@/utils/getContracts";
import { CollateralInterface } from "@/utils/Addresses";

const ReservesPage = () => {
  const [collateralDeposit, setCollateralDeposit] = useState(0);
  const [collateralWithdraw, setCollateralWithdraw] = useState(0);
  const [reservesDeposit, setReservesDeposit] = useState(0);
  const [reservesWithdraw, setReservesWithdraw] = useState(0);

  const handleCollateralDeposit = async (amount) => {
    try {
      const linkToken = await getLinkToken();
      const tx = await linkToken.approve(
        CollateralInterface,
        collateralDeposit
      );
      await tx.wait();
      const collateral = await getCollateralInterFace();
      const tx2 = await collateral.depositCollateral(collateralDeposit);
      await tx2.wait();
    } catch (e) {
      console.error(e);
    }
  };

  const handleCollateralWithdraw = (amount) => {
    setCollateralWithdraw(collateralWithdraw + amount);
  };

  const handleReservesDeposit = (amount) => {
    setReservesDeposit(reservesDeposit + amount);
  };

  const handleReservesWithdraw = (amount) => {
    setReservesWithdraw(reservesWithdraw + amount);
  };

  return (
    <>
      <Header />
      <Flex alignItems="center" justifyContent="center" w="auto" gap={8} p={10}>
        <Box
          p={8}
          borderWidth={1}
          borderRadius={8}
          boxShadow="lg"
          borderColor="#FF6B35"
        >
          <Heading mb={4} color="#FF6B35">
            Collateral
          </Heading>
          <Flex direction="column" alignItems="center" gap={4}>
            <HStack>
              <Input
                placeholder="Amount to deposit"
                variant="outline"
                borderColor={"blue"}
                size="lg"
                w="200px"
                onChange={(e) =>
                  setCollateralDeposit(parseFloat(e.target.value))
                }
              />
              <Button
                colorScheme="green"
                variant={"outline"}
                onClick={handleCollateralDeposit}
              >
                Deposit
              </Button>
            </HStack>
            <HStack>
              <Input
                placeholder="Amount to Withdraw"
                variant="outline"
                borderColor={"pink"}
                size="lg"
                w="200px"
                onChange={(e) =>
                  handleCollateralWithdraw(parseFloat(e.target.value))
                }
              />
              <Button colorScheme="red" variant={"outline"}>
                Withdraw
              </Button>
            </HStack>
            <Text>
              Current Collateral Balance:{" "}
              {collateralDeposit - collateralWithdraw}
            </Text>
          </Flex>
        </Box>

        <Box
          p={8}
          borderWidth={1}
          borderRadius={8}
          boxShadow="lg"
          borderColor="#FF6B35"
        >
          <Heading mb={4} color="#FF6B35">
            Reserves
          </Heading>
          <Flex direction="column" alignItems="center" gap={4}>
            <HStack>
              <Input
                placeholder="Amount to deposit"
                variant="outline"
                borderColor={"blue"}
                size="lg"
                w="200px"
                onChange={(e) =>
                  handleReservesDeposit(parseFloat(e.target.value))
                }
              />
              <Button colorScheme="green" variant={"outline"}>
                Deposit
              </Button>
            </HStack>
            <HStack>
              <Input
                placeholder="Amount to Withdraw"
                variant="outline"
                borderColor={"pink"}
                size="lg"
                w="200px"
                onChange={(e) =>
                  handleReservesWithdraw(parseFloat(e.target.value))
                }
              />
              <Button colorScheme="red" variant={"outline"}>
                Withdraw
              </Button>
            </HStack>
            <Text>
              Current KelCOIN Balance: {reservesDeposit - reservesWithdraw}
            </Text>
          </Flex>
        </Box>
      </Flex>
      <Center>
        <Box
          p={8}
          borderWidth={1}
          borderRadius={8}
          boxShadow="lg"
          borderColor="#FF6B35"
        >
          <Heading mb={4} color="#FF6B35">
            Mint Game Assets
          </Heading>
          <Flex direction="column" alignItems="center" gap={4}>
            <HStack>
              <Input
                placeholder="Asset Name"
                variant="outline"
                borderColor={"blue"}
                size="lg"
                w="200px"
              />
              <Button colorScheme="green" variant={"outline"}>
                Mint
              </Button>
            </HStack>
          </Flex>
        </Box>
      </Center>
    </>
  );
};

export default ReservesPage;
