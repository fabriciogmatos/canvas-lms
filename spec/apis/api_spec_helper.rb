#
# Copyright (C) 2011 Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.
#

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

# make an API call using the given method (GET/PUT/POST/DELETE),
# to the given path (e.g. /api/v1/courses). params will be verified to match the
# params generated by the Rails routing engine. body_params are params in a
# PUT/POST that are included in the body rather than the URI, and therefore
# don't affect routing.
def api_call(method, path, params, body_params = {}, headers = {})
  raw_api_call(method, path, params, body_params, headers)
  response.should be_success, response.body
  case params[:format]
  when 'json'
    response.header['content-type'].should == 'application/json; charset=utf-8'
    body = response.body
    if body.respond_to?(:call)
      StringIO.new.tap { |sio| body.call(nil, sio); body = sio.string }
    end
    JSON.parse(body)
  else
    raise("Don't know how to handle response format #{params[:format]}")
  end
end

# like api_call, but don't assume success and a json response.
def raw_api_call(method, path, params, body_params = {}, headers = {})
  path = path.sub(%r{\Ahttps?://[^/]+}, '') # remove protocol+host
  enable_forgery_protection do
    params_from_with_nesting(method, path).should == params

    if !params.key?(:api_key) && !params.key?(:access_token) && @user
      token = @user.access_tokens.first
      token ||= @user.access_tokens.create!(:purpose => 'test')
      params[:access_token] = token.token
    end

    __send__(method, path, params.reject { |k,v| %w(controller action).include?(k.to_s) }.merge(body_params), headers)
  end
end

def params_from_with_nesting(method, path)
  path, querystring = path.split('?')
  params = ActionController::Routing::Routes.recognize_path(path, :method => method)
  querystring.blank? ? params : params.merge(Rack::Utils.parse_nested_query(querystring).symbolize_keys!)
end

def api_json_response(objects, opts = nil)
  JSON.parse(objects.to_json(opts.merge(:include_root => false)))
end


