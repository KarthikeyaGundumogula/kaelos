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

const ReservesPage = () => {
  const [collateralDeposit, setCollateralDeposit] = useState(0);
  const [collateralWithdraw, setCollateralWithdraw] = useState(0);
  const [reservesDeposit, setReservesDeposit] = useState(0);
  const [reservesWithdraw, setReservesWithdraw] = useState(0);

  const handleCollateralDeposit = (amount) => {
    setCollateralDeposit(collateralDeposit + amount);
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
      <Flex h="100vh" alignItems="center" justifyContent="center" gap={8}>
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
                w="300px"
                onChange={(e) =>
                  handleCollateralDeposit(parseFloat(e.target.value))
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
                w="300px"
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
                w="300px"
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
                w="300px"
                onChange={(e) =>
                  handleReservesWithdraw(parseFloat(e.target.value))
                }
              />
              <Button colorScheme="red" variant={"outline"}>
                Withdraw
              </Button>
            </HStack>
            <Text>
              Current Reserves Balance: {reservesDeposit - reservesWithdraw}
            </Text>
          </Flex>
        </Box>
      </Flex>
    </>
  );
};

export default ReservesPage;
