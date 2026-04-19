package config

import (
	"fmt"
	"os"
)

type Config struct {
	Port    string
	DBHost  string
	DBPort  string
	DBUser  string
	DBName  string
	DBPass  string
	DataDir string
}

func Load() *Config {
	return &Config{
		Port:    getEnv("PORT", "8080"),
		DBHost:  getEnv("DB_HOST", "localhost"),
		DBPort:  getEnv("DB_PORT", "5432"),
		DBUser:  getEnv("DB_USER", os.Getenv("USER")),
		DBName:  getEnv("DB_NAME", "arcana_conquest"),
		DBPass:  getEnv("DB_PASS", ""),
		DataDir: getEnv("DATA_DIR", "../data"),
	}
}

func (c *Config) DBDSN() string {
	if c.DBPass == "" {
		return fmt.Sprintf("host=%s port=%s user=%s dbname=%s sslmode=disable",
			c.DBHost, c.DBPort, c.DBUser, c.DBName)
	}
	return fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
		c.DBHost, c.DBPort, c.DBUser, c.DBPass, c.DBName)
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
