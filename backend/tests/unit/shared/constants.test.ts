import { hasMinimumRole, USER_ROLES, ROLE_HIERARCHY } from '../../../src/shared/constants';

describe('hasMinimumRole', () => {
  it('returns true when user has exact required role', () => {
    expect(hasMinimumRole(USER_ROLES.REVIEWER, USER_ROLES.REVIEWER)).toBe(true);
  });

  it('returns true when user has higher role', () => {
    expect(hasMinimumRole(USER_ROLES.ADMIN, USER_ROLES.CONTRIBUTOR)).toBe(true);
    expect(hasMinimumRole(USER_ROLES.MODERATOR, USER_ROLES.REVIEWER)).toBe(true);
  });

  it('returns false when user has lower role', () => {
    expect(hasMinimumRole(USER_ROLES.CONTRIBUTOR, USER_ROLES.REVIEWER)).toBe(false);
    expect(hasMinimumRole(USER_ROLES.GUEST, USER_ROLES.CONTRIBUTOR)).toBe(false);
  });

  it('ADMIN is the highest role', () => {
    Object.values(USER_ROLES).forEach(role => {
      expect(hasMinimumRole(USER_ROLES.ADMIN, role)).toBe(true);
    });
  });

  it('GUEST is the lowest role', () => {
    const nonGuestRoles = Object.values(USER_ROLES).filter(r => r !== USER_ROLES.GUEST);
    nonGuestRoles.forEach(role => {
      expect(hasMinimumRole(USER_ROLES.GUEST, role)).toBe(false);
    });
  });

  it('ROLE_HIERARCHY has correct order', () => {
    expect(ROLE_HIERARCHY.GUEST).toBeLessThan(ROLE_HIERARCHY.CONTRIBUTOR);
    expect(ROLE_HIERARCHY.CONTRIBUTOR).toBeLessThan(ROLE_HIERARCHY.REVIEWER);
    expect(ROLE_HIERARCHY.REVIEWER).toBeLessThan(ROLE_HIERARCHY.MODERATOR);
    expect(ROLE_HIERARCHY.MODERATOR).toBeLessThan(ROLE_HIERARCHY.ADMIN);
  });
});
