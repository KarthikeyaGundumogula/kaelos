// GamesExplorePage.jsx
"use client";
import React from "react";
import { Grid, Heading, Box } from "@chakra-ui/react";
import GameCard from "@/components/GamerProfile/GameCard";
import Header from "@/components/Home/Header";
import Footer from "@/components/Home/Footer";

const GamesExplorePage = () => {
  const games = [
    {
      id: 1,
      title: "Fortnite",
      hours: 250,
      imageUrl: "https://via.placeholder.com/300x450",
    },
    {
      id: 2,
      title: "League of Legends",
      hours: 500,
      imageUrl: "https://via.placeholder.com/300x450",
    },
    {
      id: 3,
      title: "Minecraft",
      hours: 1000,
      imageUrl: "https://via.placeholder.com/300x450",
    },
    {
      id: 4,
      title: "Valorant",
      hours: 300,
      imageUrl: "https://via.placeholder.com/300x450",
    },
    {
      id: 5,
      title: "Apex Legends",
      hours: 400,
      imageUrl: "https://via.placeholder.com/300x450",
    },
    // Add more games as needed
  ];

  return (
    <>
      <Header />
      <Box p={8}>
        <Heading mb={8}>Explore Games</Heading>
        <Grid templateColumns="repeat(5, 1fr)" gap={6}>
          {games.map((game) => (
            <GameCard key={game.id} game={game} />
          ))}
        </Grid>
      </Box>
      <Footer />
    </>
  );
};

export default GamesExplorePage;
