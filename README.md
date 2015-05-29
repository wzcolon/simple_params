# Simple Params

A simple class to handle parameter validation, for use in APIs or Service Objects.  Simply pass in your JSON hash, and get a simple, validateable, accessible ActiveModel-like object.

This class provides the following benefits for handling params:
  * Access via array-like (params[:person][:name]), or struct-like (params.person.name) syntax
  * Ability to validate with any ActiveModel validation
  * ActiveModel-like errors, including nested error objects for nested params
  * Parameter type-coercion (e.g. transform "1" into the Integer 1)

## Installation

Add this line to your application's Gemfile:

    gem 'simple_params'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install simple_params

## Defining your Params class

All you need to do is create a class to specify accepted parameters and validations

```ruby
class MyParams < SimpleParams::Params
  param :name
  param :age, type: :integer
  param :date_of_birth, type: :date, optional: true
  param :hair_color, default: "brown", validations: { inclusion: { in: ["brown", "red", "blonde", "white"] }}

  nested_hash :address do
    param :street
    param :city
    param :zip_code, validations: { length: { in: 5..9 } }
    param :state, optional: true
    param :country, default: "USA"
  end

  # You can include whatever custom methods you need as well
  def full_address
    [address.street, address.city, address.state, address.zip_code].join(" ")
  end
end
```
We can now treat these params in very ActiveModel-like ways.  For example:

```ruby
params = MyParams.new(
  {
    name: "Bob Barker",
    age: "91",
    date_of_birth: "December 12th, 1923",
    hair_color: "white",
    address: {
      street: "7800 Beverly Blvd",
      city: "Los Angeles",
      state: "California",
      zip_code: "90036"
    }
  }
)

params.valid? #=> true
params.name #=> "Bob Barker"
params.full_address #=> "7800 Beverly Blvd Los Angeles California 90036"
```

## Validation & Errors

Errors are also treated in a very ActiveModel-like way, making it simple to validate even complexly nested inputs.

```ruby
params = MyParams.new(
  {
    name: "",
    age: "91",
    address: {
      city: "Los Angeles",
      state: "California",
      zip_code: "90036"
    }
  }
)

params.valid? #=> false
params.errors[:name] #=> ["can't be blank"]
params.errors[:address][:street] #=> ["can't be blank"]
params.address.errors[:street] #=> ["can't be blank"]

params.errors.as_json #=> {:name=>["can't be blank"], :address=>{:street=>["can't be blank"]}}
params.address.errors.as_json #=> {:street=>["can't be blank"]}
```

Custom validate methods can also be added, just as with an ActiveModel object
```ruby
class MyParams < SimpleParams::Params
  param :name
  validate :name_has_letters

  def name_has_letters
    if name.present? && !(name =~ /^[a-zA-Z]*$/)
      errors.add(:name, "must only contain letters")
    end
  end
end
```

## Defaults

It is easy to set simple or complex defaults, with either a static value or a Proc

```ruby
class DefaultParams < SimpleParams::Params
  param :name, default: "Doc Brown"
  param :first_initial, default: lambda { |params, attribute| params.name[0] }

  nested_hash :car do
    param :make, default: "DeLorean"
    param :license_plate, default: lambda { |params, attribute| params.make[0..2].upcase + "-1234" }
  end
end

params = DefaultParams.new

params.name #=> "Doc Brown"
params.first_initial #=> "D"
params.car.make #=> "DeLorean"
params.car.license_plate #=> "DEL-1234"
```

# Coercion

SimpleParams provides support for converting incoming params from one type to another.  This is extremely helpful for integers, dates, floats, and booleans, which will often come in as strings but should not be treated as such.

By default, params are assumed to be strings, so there is no need to specify String as a type.

```ruby
class CoercionParams < SimpleParams::Params
  param :name
  param :age, type: :integer
  param :date_of_birth, type: :date
  param :pocket_change, type: :decimal
end

params = CoercionParams.new(name: "Bob", age: "21", date_of_birth: "June 1st, 1980", pocket_change: "2.35")

params.name #=> "Bob"
params.age #=> 21
params.date_of_birth #=> #<Date: 1980-06-01>
params.pocket_change #=> #<BigDecimal:89ed240,'0.235E1',18(18)>
```

SimpleParams also provide helper methods for implicitly specifying the type, if you prefer that syntax.  Here is the same class as above, but redefined with these helper methods.

```ruby
class CoercionParams < SimpleParams::Params
  param :name
  integer_param :age
  date_param :date_of_birth
  decimal_param :pocket_change
end
```

# Formatters

SimpleParams also provides a way to define a formatter for your attributes.  You can use either  Proc, or a method name.  If you do the latter, the method must accept an input value, which will be the un-formatted value of your attribute.

```ruby
class FormattedParams < SimpleParams::Params
  param :name, formatter: :first_ten
  param :age, formatter: lambda { |params, age| [age, 100].min }

  def first_ten(val)
    val.first(10)
  end
end

params = FormattedParams.new(name: "Thomas Paine", age: 500)

params.name #=> "Thomas Pai"
params.age #=> 100
```

# Strict/Flexible Parameter Enforcement

By default, SimpleParams will throw an error if you try to assign a parameter not defined within your class.  However, you can override this setting to allow for flexible parameter assignment.

```ruby
class FlexibleParams < SimpleParams::Params
  allow_undefined_params
  param :name
  param :age
end

params = FlexibleParams.new(name: "Bryce", age: 30, weight: 160, dog: { name: "Bailey", breed: "Shiba Inu" })

params.name #=> "Bryce"
params.age #=> 30
params.weight #=> 160
params.dog.name #=> "Bailey"
params.dog.breed #=> "Shiba Inu"
```

# ApiPie Documentation

If your project is using [apipie-rails](http://example.com/ "apipie-rails"),
then SimpleParams is able to automatically generate the documentation markup
for apipie.

```ruby
api :POST, '/objects', "Create a object"
eval(CreateObjectParams.api_pie_documentation)
```

Note that in your SimpleParams class you can specify a few options on how the markup will be
created.

They include:
```ruby
document: false # Will not document this parameter. Default is true
optional: true # This parameter is not required. Default is false
desc: 'description of parameter' # Default is blank
```

Example:

```ruby
class CreateObjectParams < SimpleParams::Params
  param :user, type: User, document: false
  param :name, type: :string, desc: 'Name of object', validations: { presence: true }

  nested_hash :other_object do
    param :color, optional: true, validations: { presence: true }
    param :size, desc: 'Size of object', 'validations: { presence: true }
  end
end
```

# RSpec Validation Matchers

If you would like to use Simple Params built in matchers, make sure you have RSpec 
installed. Once RSpec is installed add this to your spec_helper.rb file

```ruby
RSpec.configure do |config|
  config.include(SimpleParams::ValidationMatchers)
end
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
