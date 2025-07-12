# frozen_string_literal: true

module BlueprintsCLI
  module Interfaces
    ##
    # DatabaseInterface defines the contract for database operations.
    #
    # This interface specifies the methods that any database wrapper implementation
    # must provide for CRUD operations, search functionality, and statistics.
    #
    # @example Implementing the interface
    #   class MyDatabaseWrapper
    #     include BlueprintsCLI::Interfaces::DatabaseInterface
    #
    #     def create_record(data)
    #       # Implementation here
    #     end
    #
    #     # ... other interface methods
    #   end
    module DatabaseInterface
      ##
      # Creates a new record in the database.
      #
      # @abstract
      # @param data [Hash] The data for the new record
      # @return [Hash, nil] The created record with assigned ID, or nil if creation failed
      # @raise [NotImplementedError] if not implemented
      def create_record(data)
        raise NotImplementedError, "#{self.class} must implement #create_record"
      end

      ##
      # Retrieves a record by its ID.
      #
      # @abstract
      # @param id [Integer, String] The ID of the record to retrieve
      # @return [Hash, nil] The record data, or nil if not found
      # @raise [NotImplementedError] if not implemented
      def get_record(id)
        raise NotImplementedError, "#{self.class} must implement #get_record"
      end

      ##
      # Updates an existing record.
      #
      # @abstract
      # @param id [Integer, String] The ID of the record to update
      # @param data [Hash] The updated data
      # @return [Hash, nil] The updated record, or nil if update failed
      # @raise [NotImplementedError] if not implemented
      def update_record(id, data)
        raise NotImplementedError, "#{self.class} must implement #update_record"
      end

      ##
      # Deletes a record by its ID.
      #
      # @abstract
      # @param id [Integer, String] The ID of the record to delete
      # @return [Boolean] true if the record was deleted, false otherwise
      # @raise [NotImplementedError] if not implemented
      def delete_record(id)
        raise NotImplementedError, "#{self.class} must implement #delete_record"
      end

      ##
      # Lists records with pagination support.
      #
      # @abstract
      # @param limit [Integer] The maximum number of records to return
      # @param offset [Integer] The number of records to skip
      # @return [Array<Hash>] An array of record hashes
      # @raise [NotImplementedError] if not implemented
      def list_records(limit: 100, offset: 0)
        raise NotImplementedError, "#{self.class} must implement #list_records"
      end

      ##
      # Searches records based on a query.
      #
      # @abstract
      # @param query [String] The search query
      # @param limit [Integer] The maximum number of results to return
      # @return [Array<Hash>] An array of matching record hashes
      # @raise [NotImplementedError] if not implemented
      def search_records(query, limit: 10)
        raise NotImplementedError, "#{self.class} must implement #search_records"
      end

      ##
      # Returns database statistics.
      #
      # @abstract
      # @return [Hash] A hash containing database statistics
      # @raise [NotImplementedError] if not implemented
      def stats
        raise NotImplementedError, "#{self.class} must implement #stats"
      end

      ##
      # Gets the database connection object.
      #
      # @abstract
      # @return [Object] The database connection object
      # @raise [NotImplementedError] if not implemented
      def connection
        raise NotImplementedError, "#{self.class} must implement #connection"
      end
    end
  end
end
