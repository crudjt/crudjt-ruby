require_relative 'errors/invalid_state'
require_relative 'errors/internal_error'

CRUD_JT::ERRORS = {
  '55JT01' => CRUD_JT::Errors::InvalidState,
  'XX000' => CRUD_JT::Errors::InternalError
}
