require_relative 'errors/invalid_state'
require_relative 'errors/internal_error'

CRUDJT::ERRORS = {
  '55JT01' => CRUDJT::Errors::InvalidState,
  'XX000' => CRUDJT::Errors::InternalError
}
