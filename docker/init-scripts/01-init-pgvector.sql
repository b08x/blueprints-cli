-- Initialize pgvector extension for BlueprintsCLI
-- This script runs automatically when the Docker container starts

-- Connect to the blueprints_development database
\c blueprints_development;

-- Create the vector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Grant necessary permissions
GRANT ALL PRIVILEGES ON DATABASE blueprints_development TO postgres;

-- Verify extension is installed
SELECT * FROM pg_extension WHERE extname = 'vector';

-- Create a simple test to verify pgvector is working
DO $$
BEGIN
    -- Test vector operations
    PERFORM '[1,2,3]'::vector;
    RAISE NOTICE 'pgvector extension is working correctly!';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'pgvector extension test failed: %', SQLERRM;
END $$;