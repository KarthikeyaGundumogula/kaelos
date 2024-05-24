// GameCard.jsx
import React from "react";
import { Box, Flex, Heading, Text, GridItem } from "@chakra-ui/react";

const GameCard = ({ game }) => {
  return (
    <GridItem
      position="relative"
      borderRadius={8}
      boxShadow="lg"
      borderWidth={1}
      borderColor={"blue"}
      w={"auto"}
      h="250px"
    >
      <Box
        position="absolute"
        top="0"
        left="0"
        h="full"
        backgroundImage={`url(${game.imageUrl})`}
        backgroundSize="cover"
        backgroundPosition="center"
        opacity="0.3"
      />
      <Flex
        direction="column"
        justify="flex-end"
        position="absolute"
        bottom="0"
        left="0"
        w="full"
        p={4}
        bg="rgba(0, 0, 0, 0.7)"
      >
        <Heading size="md" color="blue.500">
          {game.title}
        </Heading>
        <Text color="white">{game.hours} hrs</Text>
      </Flex>
    </GridItem>
  );
};

export default GameCard;
