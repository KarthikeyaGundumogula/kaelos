import React from "react";
import {
  Box,
  Flex,
  Heading,
  Text,
  Avatar,
  Button,
  VStack,
  Grid,
  GridItem,
  Table,
  Thead,
  Tbody,
  Tr,
  Th,
  Td,
  Center,
  TableContainer,
} from "@chakra-ui/react";
import GameCard from "@/components/GamerProfile/GameCard";
import Header from "@/components/Home/Header";
import Footer from "@/components/Home/Footer";

const GamerProfilePage = () => {
  const user = {
    name: "John Doe",
    email: "john@example.com",
    avatarUrl: "https://via.placeholder.com/150",
    gamerTag: "JohnD123",
    games: [
      {
        title: "Fortnite",
        hours: 250,
        imageUrl: "https://via.placeholder.com/300x450",
      },
      {
        title: "Apex Legends",
        hours: 150,
        imageUrl: "https://via.placeholder.com/300x450",
      },
      {
        title: "Valorant",
        hours: 100,
        imageUrl: "https://via.placeholder.com/300x450",
      },
      {
        title: "League of Legends",
        hours: 300,
        imageUrl: "https://via.placeholder.com/300x450",
      },
      {
        title: "Dota 2",
        hours: 200,
        imageUrl: "https://via.placeholder.com/300x450",
      },
      {
        title: "Counter-Strike: Global Offensive",
        hours: 400,
        imageUrl: "https://via.placeholder.com/300x450",
      },
    ],
    friends: [
      { name: "Jane Doe", gamerTag: "JaneD456" },
      { name: "Bob Smith", gamerTag: "BobS789" },
      { name: "Alice Johnson", gamerTag: "AliceJ012" },
      { name: "Tom Wilson", gamerTag: "TomW345" },
    ],
  };

  return (
    <>
      <Header />
      <Box m={10}>
        <Center>
          <VStack>
            <Avatar size="xl" name={user.name} src={user.avatarUrl} />
            <Heading size="lg" color="blue.500">
              {user.name}
            </Heading>
            <Text color="white">{user.email}</Text>
            <Text color="white">Gamer Tag: {user.gamerTag}</Text>
            <Button colorScheme="blue">Edit Profile</Button>
          </VStack>
        </Center>
        <Heading size="md" color="blue.500">
          Games
        </Heading>
        <Grid templateColumns="repeat(4, 1fr)" gap={6} m={5}>
          {user.games.map((game, index) => (
            <GameCard key={index} game={game} />
          ))}
        </Grid>
        <Heading size="md" color="blue.500">
          Gamer Friends
        </Heading>
        <Center>
          <TableContainer
            borderRadius={12}
            borderWidth={1}
            borderColor={"blue"}
          >
            <Table variant={"simple"} color="white" size={"lg"}>
              <Thead>
                <Tr>
                  <Th textAlign={"center"} color={"blue.500"}>
                    Name
                  </Th>
                  <Th color={"blue.500"} textAlign={"center"}>
                    Gamer Tag
                  </Th>
                </Tr>
              </Thead>
              <Tbody>
                {user.friends.map((friend, index) => (
                  <Tr key={index}>
                    <Td textAlign={"center"}>{friend.name}</Td>
                    <Td textAlign={"center"}>{friend.gamerTag}</Td>
                  </Tr>
                ))}
              </Tbody>
            </Table>
          </TableContainer>
        </Center>
      </Box>
      <Footer />
    </>
  );
};

export default GamerProfilePage;
