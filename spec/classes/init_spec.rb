require 'spec_helper'
describe 'obijictrl' do
  context 'with default values for all parameters' do
    it { should contain_class('obijictrl') }
  end
end
