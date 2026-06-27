export interface User {
  id: number;
  username: string;
  nickname: string;
  email: string | null;
  phone: string;
  role: 'USER' | 'ADMIN';
  realNameVerified: boolean;
  createdAt: string;
}

export interface UserPage {
  records: User[];
  total: number;
  page: number;
  size: number;
}
