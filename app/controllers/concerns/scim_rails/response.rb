# frozen_string_literal: true

module ScimRails
  module Response
    CONTENT_TYPE = "application/scim+json"

    def json_response(object, status = :ok)
      render \
        json: object,
        status: status,
        content_type: CONTENT_TYPE
    end

    def json_scim_response(object:, status: :ok, counts: nil)
      case params[:action]
      when "index"
        render \
          json: list_response(object, counts),
          status: status,
          content_type: CONTENT_TYPE
      when "show", "create", "put_update", "patch_update"
        render \
          json: object_response(object),
          status: status,
          content_type: CONTENT_TYPE
      end
    end

    private

    def list_response(object, counts)
      object = object
        .order(:id)
        .offset(counts.offset)
        .limit(counts.limit)
      {
        schemas: [
          "urn:ietf:params:scim:api:messages:2.0:ListResponse"
        ],
        totalResults: counts.total,
        startIndex: counts.start_index,
        itemsPerPage: counts.limit,
        Resources: list_objects(object)
      }
    end

    def list_objects(objects)
      objects.map do |object|
        object_response(object)
      end
    end

    def object_response(object)
      schema = case object
               when ScimRails.config.scim_users_model
                 ScimRails.config.user_schema
               when ScimRails.config.scim_groups_model
                 ScimRails.config.group_schema
               else
                 raise ScimRails::ExceptionHandler::InvalidQuery,
                       "Unknown model: #{object}"
               end
      find_value(object, schema)
    end

    # `find_value` is a recursive method that takes a "user" and a
    # "user schema" and replaces any symbols in the schema with the
    # corresponding value from the user. Given a schema with symbols,
    # `find_value` will search through the object for the symbols,
    # send those symbols to the model, and replace the symbol with
    # the return value.

    def find_value(object, schema)
      case schema
      when Hash
        schema.each.with_object({}) do |(key, value), hash|
          hash[key] = find_value(object, value)
        end
      when Array, ActiveRecord::Associations::CollectionProxy
        schema.map do |value|
          find_value(object, value)
        end
      when ScimRails.config.scim_users_model
        find_value(schema, ScimRails.config.user_abbreviated_schema)
      when ScimRails.config.scim_groups_model
        find_value(schema, ScimRails.config.group_abbreviated_schema)
      when Symbol
        find_value(object, object.public_send(schema))
      else
        schema
      end
    end
  end
end
