-- BlueprintsCLI Database Schema
-- PostgreSQL with pgvector extension for vector similarity search
-- This schema supports blueprint storage, categorization, and AI-powered features

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "vector";

-- Drop existing tables if they exist (for development)
-- WARNING: This will delete all data - use with caution in production
DROP TABLE IF EXISTS blueprint_categories CASCADE;
DROP TABLE IF EXISTS categories CASCADE;
DROP TABLE IF EXISTS blueprints CASCADE;

-- Create categories table
-- Stores blueprint categories for organization and filtering
CREATE TABLE categories (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) UNIQUE NOT NULL,
  description TEXT,
  color VARCHAR(7), -- Hex color code for UI display
  icon VARCHAR(50), -- Icon name or class for UI display
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create blueprints table
-- Main table for storing code blueprints with vector embeddings
CREATE TABLE blueprints (
  id SERIAL PRIMARY KEY,
  uuid UUID DEFAULT uuid_generate_v4() UNIQUE NOT NULL,
  name VARCHAR(255) NOT NULL,
  description TEXT NOT NULL,
  code TEXT NOT NULL,
  language VARCHAR(50) NOT NULL DEFAULT 'javascript',
  framework VARCHAR(50),
  type VARCHAR(50), -- component, utility, service, etc.
  complexity VARCHAR(20) CHECK (complexity IN ('low', 'medium', 'high')),
  estimated_lines INTEGER,
  
  -- Vector embedding for similarity search (OpenAI ada-002 dimensions)
  vector vector(1536),
  
  -- Metadata for search and filtering
  tags TEXT[], -- Array of tags for flexible categorization
  author VARCHAR(100),
  license VARCHAR(50),
  version VARCHAR(20) DEFAULT '1.0.0',
  
  -- Usage statistics
  view_count INTEGER DEFAULT 0,
  use_count INTEGER DEFAULT 0,
  
  -- Timestamps
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Search optimization
  search_vector tsvector GENERATED ALWAYS AS (
    to_tsvector('english', 
      coalesce(name, '') || ' ' ||
      coalesce(description, '') || ' ' ||
      coalesce(array_to_string(tags, ' '), '')
    )
  ) STORED
);

-- Create many-to-many relationship table for blueprint categories
CREATE TABLE blueprint_categories (
  blueprint_id INTEGER NOT NULL REFERENCES blueprints(id) ON DELETE CASCADE,
  category_id INTEGER NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  PRIMARY KEY (blueprint_id, category_id)
);

-- Create indexes for performance optimization

-- Blueprint indexes
CREATE INDEX idx_blueprints_name ON blueprints(name);
CREATE INDEX idx_blueprints_language ON blueprints(language);
CREATE INDEX idx_blueprints_framework ON blueprints(framework);
CREATE INDEX idx_blueprints_type ON blueprints(type);
CREATE INDEX idx_blueprints_complexity ON blueprints(complexity);
CREATE INDEX idx_blueprints_author ON blueprints(author);
CREATE INDEX idx_blueprints_created_at ON blueprints(created_at DESC);
CREATE INDEX idx_blueprints_updated_at ON blueprints(updated_at DESC);
CREATE INDEX idx_blueprints_view_count ON blueprints(view_count DESC);
CREATE INDEX idx_blueprints_use_count ON blueprints(use_count DESC);

-- Vector similarity search index (HNSW for fast approximate nearest neighbor search)
CREATE INDEX idx_blueprints_vector ON blueprints 
USING hnsw (vector vector_cosine_ops) 
WITH (m = 16, ef_construction = 64);

-- Full-text search index
CREATE INDEX idx_blueprints_search_vector ON blueprints USING GIN(search_vector);

-- Array tags index
CREATE INDEX idx_blueprints_tags ON blueprints USING GIN(tags);

-- Category indexes
CREATE INDEX idx_categories_name ON categories(name);
CREATE INDEX idx_categories_created_at ON categories(created_at);

-- Junction table indexes
CREATE INDEX idx_blueprint_categories_blueprint_id ON blueprint_categories(blueprint_id);
CREATE INDEX idx_blueprint_categories_category_id ON blueprint_categories(category_id);

-- Create updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply updated_at triggers
CREATE TRIGGER update_blueprints_updated_at 
  BEFORE UPDATE ON blueprints 
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_categories_updated_at 
  BEFORE UPDATE ON categories 
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Insert default categories
INSERT INTO categories (name, description, color, icon) VALUES
('component', 'Reusable UI components and widgets', '#3b82f6', 'component'),
('utility', 'Helper functions and utilities', '#10b981', 'tool'),
('service', 'Service classes and API integrations', '#f59e0b', 'service'),
('hook', 'Custom hooks and state management', '#8b5cf6', 'hook'),
('api', 'API endpoints and server routes', '#ef4444', 'api'),
('database', 'Database queries and models', '#06b6d4', 'database'),
('authentication', 'Authentication and authorization', '#f97316', 'lock'),
('testing', 'Test cases and testing utilities', '#84cc16', 'test'),
('configuration', 'Configuration files and setup', '#6b7280', 'settings'),
('deployment', 'Deployment scripts and configurations', '#ec4899', 'deploy');

-- Create function for vector similarity search
CREATE OR REPLACE FUNCTION search_blueprints_by_similarity(
  query_vector vector(1536),
  similarity_threshold FLOAT DEFAULT 0.7,
  result_limit INTEGER DEFAULT 10
)
RETURNS TABLE(
  id INTEGER,
  name VARCHAR(255),
  description TEXT,
  similarity FLOAT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    b.id,
    b.name,
    b.description,
    1 - (b.vector <=> query_vector) AS similarity
  FROM blueprints b
  WHERE b.vector IS NOT NULL
    AND (1 - (b.vector <=> query_vector)) >= similarity_threshold
  ORDER BY b.vector <=> query_vector
  LIMIT result_limit;
END;
$$ LANGUAGE plpgsql;

-- Create function for full-text search with ranking
CREATE OR REPLACE FUNCTION search_blueprints_by_text(
  search_query TEXT,
  result_limit INTEGER DEFAULT 20
)
RETURNS TABLE(
  id INTEGER,
  name VARCHAR(255),
  description TEXT,
  rank REAL
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    b.id,
    b.name,
    b.description,
    ts_rank(b.search_vector, plainto_tsquery('english', search_query)) AS rank
  FROM blueprints b
  WHERE b.search_vector @@ plainto_tsquery('english', search_query)
  ORDER BY rank DESC
  LIMIT result_limit;
END;
$$ LANGUAGE plpgsql;

-- Create function to increment view count
CREATE OR REPLACE FUNCTION increment_blueprint_view_count(blueprint_id INTEGER)
RETURNS VOID AS $$
BEGIN
  UPDATE blueprints 
  SET view_count = view_count + 1 
  WHERE id = blueprint_id;
END;
$$ LANGUAGE plpgsql;

-- Create function to increment use count
CREATE OR REPLACE FUNCTION increment_blueprint_use_count(blueprint_id INTEGER)
RETURNS VOID AS $$
BEGIN
  UPDATE blueprints 
  SET use_count = use_count + 1 
  WHERE id = blueprint_id;
END;
$$ LANGUAGE plpgsql;

-- Create view for blueprint statistics
CREATE VIEW blueprint_stats AS
SELECT 
  language,
  framework,
  COUNT(*) as total_blueprints,
  AVG(view_count) as avg_views,
  AVG(use_count) as avg_uses,
  MAX(created_at) as latest_created
FROM blueprints
GROUP BY language, framework
ORDER BY total_blueprints DESC;

-- Create view for popular blueprints
CREATE VIEW popular_blueprints AS
SELECT 
  id,
  name,
  description,
  language,
  framework,
  view_count,
  use_count,
  (view_count + use_count * 2) as popularity_score,
  created_at
FROM blueprints
WHERE (view_count + use_count) > 0
ORDER BY popularity_score DESC;

-- Grant permissions for application user
-- Note: In production, create a dedicated application user with limited permissions
-- GRANT USAGE ON SCHEMA public TO blueprints_app;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO blueprints_app;
-- GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO blueprints_app;
-- GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO blueprints_app;

-- Insert sample data for development and testing
INSERT INTO blueprints (name, description, code, language, framework, type, complexity, tags) VALUES
('React Button Component', 
 'A reusable button component with customizable styling and click handlers',
 'import React from ''react'';

const Button = ({ 
  children, 
  onClick, 
  variant = ''primary'', 
  disabled = false,
  className = ''''
}) => {
  const baseClasses = ''px-4 py-2 rounded font-medium transition-colors'';
  const variantClasses = {
    primary: ''bg-blue-600 text-white hover:bg-blue-700'',
    secondary: ''bg-gray-600 text-white hover:bg-gray-700'',
    outline: ''border-2 border-blue-600 text-blue-600 hover:bg-blue-600 hover:text-white''
  };

  return (
    <button
      onClick={onClick}
      disabled={disabled}
      className={`${baseClasses} ${variantClasses[variant]} ${disabled ? ''opacity-50 cursor-not-allowed'' : ''''} ${className}`}
    >
      {children}
    </button>
  );
};

export default Button;',
 'javascript', 'react', 'component', 'low', ARRAY['component', 'button', 'ui', 'react']),

('Python Data Validator',
 'A utility class for validating and sanitizing user input data',
 'from typing import Any, Dict, List, Optional
import re

class DataValidator:
    """Utility class for validating and sanitizing user input."""
    
    @staticmethod
    def validate_email(email: str) -> bool:
        """Validate email format using regex."""
        pattern = r''^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$''
        return bool(re.match(pattern, email))
    
    @staticmethod
    def validate_phone(phone: str) -> bool:
        """Validate phone number format."""
        pattern = r''^\+?1?[-.\s]?\(?[0-9]{3}\)?[-.\s]?[0-9]{3}[-.\s]?[0-9]{4}$''
        return bool(re.match(pattern, phone))
    
    @staticmethod
    def sanitize_string(text: str, max_length: int = 255) -> str:
        """Sanitize string input by removing harmful characters."""
        if not isinstance(text, str):
            return """"
        
        # Remove potential XSS characters
        sanitized = re.sub(r''[<>""''&]'', '''', text)
        return sanitized[:max_length].strip()
    
    @staticmethod
    def validate_required_fields(data: Dict[str, Any], required_fields: List[str]) -> List[str]:
        """Check for missing required fields in data dictionary."""
        missing_fields = []
        for field in required_fields:
            if field not in data or not data[field]:
                missing_fields.append(field)
        return missing_fields',
 'python', 'none', 'utility', 'medium', ARRAY['validation', 'utility', 'security', 'python']);

-- Update blueprint categories junction table
INSERT INTO blueprint_categories (blueprint_id, category_id)
SELECT b.id, c.id
FROM blueprints b, categories c
WHERE (b.name = 'React Button Component' AND c.name IN ('component'))
   OR (b.name = 'Python Data Validator' AND c.name IN ('utility'));

-- Create comments for documentation
COMMENT ON TABLE blueprints IS 'Stores code blueprints with metadata and vector embeddings for similarity search';
COMMENT ON TABLE categories IS 'Organizational categories for blueprints';
COMMENT ON TABLE blueprint_categories IS 'Many-to-many relationship between blueprints and categories';
COMMENT ON COLUMN blueprints.vector IS 'Vector embedding for semantic similarity search (1536 dimensions for OpenAI ada-002)';
COMMENT ON COLUMN blueprints.search_vector IS 'Full-text search vector generated from name, description, and tags';
COMMENT ON COLUMN blueprints.tags IS 'Array of tags for flexible categorization and filtering';

-- Final verification queries (uncomment to run)
-- SELECT 'Categories created:', COUNT(*) FROM categories;
-- SELECT 'Blueprints created:', COUNT(*) FROM blueprints;
-- SELECT 'Blueprint-Category associations created:', COUNT(*) FROM blueprint_categories;