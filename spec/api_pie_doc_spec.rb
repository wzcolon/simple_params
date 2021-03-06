require 'spec_helper'
require 'fixtures/dummy_params'

describe SimpleParams::ApiPieDoc do

  let(:api_pie_doc) { SimpleParams::ApiPieDoc.new(DummyParams) }

  describe "#initialize" do
    specify "should give object base_attributes" do
      expect(api_pie_doc.base_attributes).to include(name: { type: :string })
      expect(api_pie_doc.base_attributes).to include(age: { optional: true, type: :integer })
      expect(api_pie_doc.base_attributes.keys).to include(:amount, :color, :first_initial)
    end

    specify "should give object nested_classes" do
      expect(api_pie_doc.nested_classes.keys).to eq [:address, :phone, :dogs]
    end

    specify "should call #build_nested_attributes" do
      expect_any_instance_of(SimpleParams::ApiPieDoc).to receive(:build_nested_classes)
      api_pie_doc
    end

    specify "should give object nested_attributes" do
      expect(api_pie_doc.nested_attributes.flat_map(&:keys)).to include(:address, :phone, :dogs)
      expect(api_pie_doc.nested_attributes[0].values.flat_map(&:keys)).to eq [:street, :city, :zip_code, :state, :type]
      expect(api_pie_doc.nested_attributes[1].values.flat_map(&:keys)).to eq [:cell_phone, :phone_number, :area_code, :type]
      expect(api_pie_doc.nested_attributes[2].values.flat_map(&:keys)).to eq [:name, :age, :type]
    end

    specify "should give object docs" do
      expect(api_pie_doc.docs).to eq []
    end
  end

  describe "#build" do
    specify "should return a string of api_pie documentation params" do
      expect(api_pie_doc.build).to be_a String
    end
  end
end
