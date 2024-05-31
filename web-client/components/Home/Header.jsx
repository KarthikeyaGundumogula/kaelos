// Header.jsx
import React from "react";
import {
  Center,
  Flex,
  Heading,
  Link,
  Button,
  HStack,
  Box,
} from "@chakra-ui/react";
import NextLink from "next/link";
import Head from "next/head";

const Header = () => {
  return (
    <Box>
      <Center bg="black" m={3}>
        <HStack>
          <Heading color="blue" mr={80} ml={2}>
            <NextLink href="/" passHref>
              <Link>Utopian DAO</Link>
            </NextLink>
          </Heading>
          <Nav />
        </HStack>
      </Center>
    </Box>
  );
};

const Nav = () => {
  return (
    <HStack spacing={16} color="white">
      <NextLink href="/games" passHref>
        <Heading size={"md"}>
          <Link color="blue">Games</Link>
        </Heading>
      </NextLink>
      <NextLink href="/profile/kkk" passHref>
        <Heading size={"md"}>
          <Link color="blue">Profile</Link>
        </Heading>
      </NextLink>
      <NextLink href="/reserves" passHref>
        <Heading size={"md"}>
          <Link color="blue">Vaults</Link>
        </Heading>
      </NextLink>
      <NextLink href="/login" passHref>
        <Heading size={"md"}>
          <Link color="blue">Login</Link>
        </Heading>
      </NextLink>
      <NextLink href="/register" passHref>
        <Heading size={"md"}>
          <Link color="blue">Register</Link>
        </Heading>
      </NextLink>
    </HStack>
  );
};

export default Header;
