export interface Feedback {
  id: number;
  userId: number;
  type: 'bug' | 'suggestion' | 'other';
  content: string;
  imageUrls: string[];
  status: 'pending' | 'processing' | 'resolved' | 'closed';
  adminReply: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface FeedbackPage {
  records: Feedback[];
  total: number;
  page: number;
  size: number;
}
