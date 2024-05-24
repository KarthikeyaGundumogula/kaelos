import React from "react";
import { Box, Flex, Heading, Text, Button, Image } from "@chakra-ui/react";
import Header from "@/components/Home/Header";
import Footer from "@/components/Home/Footer";

const LandingPage = () => {
  return (
    <>
      <Box bg="black" color="white">
        <Header />
        <Flex
          direction={{ base: "column", md: "row" }}
          align="center"
          justify="center"
          p={12}
        >
          <Box mr={{ md: 12 }}>
            <Heading size="4xl" mb={6} color="blue.400">
              Manage Your Games with Utopian Games
            </Heading>
            <Text fontSize="xl" mb={8}>
              Utopian Games is a powerful game management platform that helps
              you streamline your gaming operations.
            </Text>
            <Button colorScheme="blue" size="lg">
              Get Started
            </Button>
          </Box>
          <Image
            src="/game-management.png"
            alt="Game Management"
            boxSize={{ base: "300px", md: "400px" }}
            mt={{ base: 8, md: 0 }}
          />
        </Flex>

        <Box bg="black" color="white" py={12}>
          <Heading size="4xl" textAlign="center" mb={8} color="blue.400">
            Features
          </Heading>
          <Flex
            direction={{ base: "column", md: "row" }}
            justify="center"
            align="center"
            textAlign={{ base: "center", md: "left" }}
            px={6}
          >
            <Box mr={{ md: 12 }} mb={{ base: 8, md: 0 }}>
              <Heading size="2xl" mb={4} color="blue.400">
                Game Tracking
              </Heading>
              <Text fontSize="xl">
                Easily track and manage your games, players, and tournaments.
              </Text>
            </Box>
            <Box mr={{ md: 12 }} mb={{ base: 8, md: 0 }}>
              <Heading size="2xl" mb={4} color="blue.400">
                Analytics
              </Heading>
              <Text fontSize="xl">
                Get detailed analytics and insights to improve your gaming
                operations.
              </Text>
            </Box>
            <Box>
              <Heading size="2xl" mb={4} color="blue.400">
                Collaboration
              </Heading>
              <Text fontSize="xl">
                Invite team members and collaborate on game management tasks.
              </Text>
            </Box>
          </Flex>
        </Box>

        <Flex
          direction={{ base: "column", md: "row" }}
          align="center"
          justify="center"
          p={12}
        >
          <Image
            src="/game-dashboard.png"
            alt="Game Dashboard"
            boxSize={{ base: "300px", md: "400px" }}
            mr={{ md: 12 }}
            mb={{ base: 8, md: 0 }}
          />
          <Box>
            <Heading size="4xl" mb={6} color="blue.400">
              Streamline Your Gaming Operations
            </Heading>
            <Text fontSize="xl" mb={8}>
              Utopian Games provides a comprehensive solution to manage all
              aspects of your gaming business.
            </Text>
            <Button colorScheme="blue" size="lg">
              Try It Now
            </Button>
          </Box>
        </Flex>
      </Box>
      <Footer />
    </>
  );
};

export default LandingPage;
