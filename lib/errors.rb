require_relative 'errors/donate_exception'
require_relative 'errors/internal_error'

CRUD_JT::ERRORS = {
  'DE000' => CRUD_JT::Errors::DonateException,
  'XX000' => CRUD_JT::Errors::InternalError
}
