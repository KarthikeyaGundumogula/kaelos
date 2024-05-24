// Header.jsx
import React from "react";
import { Center, Flex, Heading, Link, Button, HStack } from "@chakra-ui/react";
import NextLink from "next/link";
import Head from "next/head";

const Header = () => {
  return (
    <Center bg="black" m={5}>
      <HStack>
        <Heading color="blue.500" mr={80}>
          <NextLink href="/" passHref>
            <Link>Utopian Games</Link>
          </NextLink>
        </Heading>
        <Nav />
      </HStack>
    </Center>
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
      <NextLink href="/settings" passHref>
        <Heading size={"md"}>
          <Link color="blue">Settings</Link>
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
