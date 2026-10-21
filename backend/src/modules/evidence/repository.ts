import mongoose, { ClientSession } from 'mongoose';
import { EvidenceModel, IEvidence } from './evidence.model';
import { CreateEvidenceInput } from './validation';

export class EvidenceRepository {
  async create(
    data: CreateEvidenceInput & { uploadedBy: string },
    session?: ClientSession
  ): Promise<IEvidence> {
    const evidence = new EvidenceModel({
      claimId: new mongoose.Types.ObjectId(data.claimId),
      sourceType: data.sourceType,
      title: data.title.trim(),
      description: data.description.trim(),
      url: data.url ? data.url.trim() : null,
      documentRef: data.documentRef ? data.documentRef.trim() : null,
      dateOfEvidence: data.dateOfEvidence ? new Date(data.dateOfEvidence) : null,
      languageOfEvidence: data.languageOfEvidence || 'en',
      uploadedBy: new mongoose.Types.ObjectId(data.uploadedBy),
      uploadedAt: new Date(),
    });

    return await evidence.save({ session });
  }

  async findById(id: string, session?: ClientSession): Promise<IEvidence | null> {
    if (!mongoose.Types.ObjectId.isValid(id)) return null;
    const q = EvidenceModel.findById(id);
    if (session) q.session(session);
    return await q.exec();
  }

  async findByClaimId(claimId: string, session?: ClientSession): Promise<IEvidence[]> {
    if (!mongoose.Types.ObjectId.isValid(claimId)) return [];
    const q = EvidenceModel.find({ claimId: new mongoose.Types.ObjectId(claimId) }).sort({ uploadedAt: -1 });
    if (session) q.session(session);
    return await q.exec();
  }

  async update(id: string, updateData: any, session?: ClientSession): Promise<IEvidence | null> {
    if (!mongoose.Types.ObjectId.isValid(id)) return null;
    return await EvidenceModel.findByIdAndUpdate(id, updateData, { new: true, session }).exec();
  }
}

export const evidenceRepository = new EvidenceRepository();

