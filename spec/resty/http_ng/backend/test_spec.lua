local test_backend = require 'resty.http_ng.backend.test'
local request = require 'resty.http_ng.request'

local backend

describe('test backend',function()
  before_each(function() backend = test_backend.new() end)

  describe('matching expectations', function()
    it('allows setting expectations', function()
      backend.expect{method = 'GET'}.respond_with{status = 301 }

      local req = request.new{method = 'GET', url = 'http://example.com' }
      local response = backend.send(req)

      assert.truthy(response)
    end)

    it('can verify outstanding requests', function()
      assert.has.no_error(backend.verify_no_outstanding_expectations)
      backend.expect{method = 'GET' }
      assert.has.error(backend.verify_no_outstanding_expectations, 'has 1 outstanding expectations')
    end)

    it('expects a request', function()
      local req = request.new{method = 'GET', url = 'http://example.com' }
      assert.has.error(function() backend.send(req) end, 'no expectation')
    end)

    it('matches expectation', function()
      backend.expect{method = 'POST'}
      local req = request.new{method = 'GET', url = 'http://example.com' }
      assert.has.error(function() backend.send(req) end, 'expectation does not match')
    end)
  end)
end)
