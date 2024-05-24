"use client";
import React, { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import Header from "@/components/Home/Header";
import {
  Box,
  Flex,
  Heading,
  Button,
  Text,
  Avatar,
  VStack,
} from "@chakra-ui/react";

const GamerProfilePage = () => {
  const router = useRouter();
  const [user, setUser] = useState(null);

  useEffect(() => {
    // Fetch user data from an API or local storage
    const fetchUser = async () => {
      try {
        const response = await fetch("/api/user");
        const userData = await response.json();
        setUser(userData);
      } catch (error) {
        console.error("Error fetching user data:", error);
      }
    };
    fetchUser();
  }, []);

  const handleSignIn = () => {
    router.push("/signin");
  };

  return (
    <>
      <Header />
      <Flex direction="column" align="center" justify="center" minH="100vh">
        {user ? (
          <Box
            p={8}
            borderRadius={8}
            boxShadow="lg"
            w={{ base: "90%", md: "60%", lg: "40%" }}
          >
            <VStack spacing={6}>
              <Avatar size="xl" name={user.name} src={user.avatarUrl} />
              <Heading size="lg">{user.name}</Heading>
              <Text>{user.email}</Text>
              <Button
                colorScheme="blue"
                onClick={() => router.push(`/gamers/${user.id}`)}
              >
                View Profile
              </Button>
            </VStack>
          </Box>
        ) : (
          <Box>
            <VStack spacing={6}>
              <Heading size="lg">Welcome to Gamer Profile</Heading>
              <Text>Please sign in to view your profile.</Text>
              <Button colorScheme="blue" onClick={handleSignIn}>
                Sign In
              </Button>
            </VStack>
          </Box>
        )}
      </Flex>
    </>
  );
};

export default GamerProfilePage;
